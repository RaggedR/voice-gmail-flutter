import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';

import '../domain/speech_recognizer.dart';

/// Deepgram streaming speech recognition using WebSocket
class DeepgramSpeechRecognizer implements SpeechRecognizer {
  final AudioRecorder _recorder = AudioRecorder();
  WebSocket? _webSocket;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isListening = false;
  bool _isInitialized = false;

  // Callbacks
  void Function(String text)? _onResult;
  void Function(String error)? _onError;
  void Function()? _onDone;

  // Transcript accumulation
  String _currentTranscript = '';
  Timer? _silenceTimer;
  Timer? _keepAliveTimer;

  String get _apiKey => dotenv.env['DEEPGRAM_API_KEY'] ?? '';

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get isAvailable async {
    if (_apiKey.isEmpty) {
      debugPrint('Deepgram API key not configured');
      return false;
    }
    return await _recorder.hasPermission();
  }

  @override
  Future<bool> initialize() async {
    print('[Deepgram] initialize() called, _isInitialized=$_isInitialized');
    if (_isInitialized) return true;

    if (_apiKey.isEmpty) {
      print('[Deepgram] ERROR: API key is empty!');
      return false;
    }
    print('[Deepgram] API key present (${_apiKey.length} chars)');

    final hasPermission = await _recorder.hasPermission();
    print('[Deepgram] Microphone permission: $hasPermission');
    if (!hasPermission) {
      print('[Deepgram] ERROR: No microphone permission');
      return false;
    }

    _isInitialized = true;
    print('[Deepgram] Initialized successfully');
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String error)? onError,
    void Function()? onDone,
  }) async {
    print('[Deepgram] startListening called');

    if (!_isInitialized) {
      print('[Deepgram] Not initialized, initializing now...');
      final success = await initialize();
      if (!success) {
        print('[Deepgram] Initialization FAILED');
        onError?.call('Deepgram not available');
        onDone?.call();
        return;
      }
      print('[Deepgram] Initialization successful');
    }

    if (_isListening) {
      print('[Deepgram] Already listening, stopping first...');
      await stopListening();
    }

    _onResult = onResult;
    _onError = onError;
    _onDone = onDone;
    _currentTranscript = '';
    _isListening = true;

    try {
      print('[Deepgram] Connecting to WebSocket...');
      // Connect to Deepgram WebSocket
      final url = 'wss://api.deepgram.com/v1/listen'
          '?encoding=linear16'
          '&sample_rate=16000'
          '&channels=1'
          '&model=nova-2'
          '&language=en-US'
          '&punctuate=true'
          '&interim_results=true'
          '&endpointing=1000'  // Wait 1s of silence before ending utterance
          '&utterance_end_ms=2000'  // Wait 2s before utterance end event
          '&vad_events=true';  // Voice activity detection

      _webSocket = await WebSocket.connect(
        url,
        headers: {'Authorization': 'Token $_apiKey'},
      );

      print('[Deepgram] WebSocket CONNECTED!');
      print('\n[Listening... say "Porcupine" + command]\n');

      // Send keepalive pings every 5 seconds to prevent timeout
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
          _webSocket!.add(jsonEncode({'type': 'KeepAlive'}));
        }
      });

      // Handle incoming transcripts
      _webSocket!.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('[Deepgram] WebSocket ERROR: $error');
          _onError?.call('Connection error');
          _cleanup();
        },
        onDone: () {
          print('[Deepgram] WebSocket CLOSED');
          _cleanup();
        },
      );

      // Start streaming audio to WebSocket
      print('[Deepgram] Starting audio stream...');
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      print('[Deepgram] Audio stream started!');

      int chunkCount = 0;
      _audioSubscription = stream.listen(
        (chunk) {
          if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
            _webSocket!.add(chunk);
            chunkCount++;
            if (chunkCount == 1) {
              print('[Audio] First chunk received! (${chunk.length} bytes)');
            }
            if (chunkCount % 100 == 0) {
              print('[Audio] Sent $chunkCount chunks');
            }
          } else {
            print('[Audio] WebSocket not open, state: ${_webSocket?.readyState}');
          }
        },
        onError: (e) {
          print('[Audio] Stream error: $e');
        },
      );

    } catch (e) {
      print('[Deepgram] EXCEPTION: $e');
      _onError?.call('Failed to start: $e');
      _isListening = false;
      _onDone?.call();
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);

      // Skip non-object messages (arrays, metadata, etc.)
      if (decoded is! Map<String, dynamic>) {
        print('[Deepgram] Non-map message: ${data.toString().substring(0, 100)}...');
        return;
      }

      final json = decoded;

      // Debug: show message type
      final msgType = json['type'] as String?;
      if (msgType != null && msgType != 'Results') {
        print('[Deepgram] Message type: $msgType');
      }

      // Check for transcript
      final channel = json['channel'] as Map<String, dynamic>?;
      final alternatives = channel?['alternatives'] as List<dynamic>?;

      if (alternatives != null && alternatives.isNotEmpty) {
        final transcript = alternatives[0]['transcript'] as String?;
        final isFinal = json['is_final'] as bool? ?? false;
        final speechFinal = json['speech_final'] as bool? ?? false;

        if (transcript != null && transcript.isNotEmpty) {
          if (isFinal) {
            _currentTranscript += (transcript + ' ');

            // Reset silence timer on each final transcript
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 1200), () {
              // Silence detected - deliver the accumulated transcript
              if (_currentTranscript.trim().isNotEmpty) {
                final finalText = _currentTranscript.trim();
                print('\n========================================');
                print('YOU SAID: "$finalText"');
                print('========================================\n');
                _onResult?.call(finalText);
                _currentTranscript = '';
              }
            });
          }

          // If speech_final, deliver immediately
          if (speechFinal && _currentTranscript.trim().isNotEmpty) {
            _silenceTimer?.cancel();
            final finalText = _currentTranscript.trim();
            print('\n========================================');
            print('YOU SAID: "$finalText"');
            print('========================================\n');
            _onResult?.call(finalText);
            _currentTranscript = '';
          }
        }
      }

      // Check for utterance end
      if (json['type'] == 'UtteranceEnd') {
        _silenceTimer?.cancel();
        if (_currentTranscript.trim().isNotEmpty) {
          final finalText = _currentTranscript.trim();
          print('\n========================================');
          print('YOU SAID: "$finalText"');
          print('========================================\n');
          _onResult?.call(finalText);
          _currentTranscript = '';
        }
      }

    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void _cleanup() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isListening = false;
    _onDone?.call();
  }

  @override
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_webSocket != null) {
      await _webSocket!.close();
      _webSocket = null;
    }

    await _recorder.stop();
    _isListening = false;
  }

  @override
  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}
