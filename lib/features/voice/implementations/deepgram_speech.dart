import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
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
  DateTime? _lastTranscriptTime;

  // Reconnection protection
  DateTime? _lastConnectionAttempt;
  int _rapidReconnectCount = 0;

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

    // Protect against rapid reconnection loops
    final now = DateTime.now();
    if (_lastConnectionAttempt != null) {
      final elapsed = now.difference(_lastConnectionAttempt!).inMilliseconds;
      if (elapsed < 1000) {
        _rapidReconnectCount++;
        if (_rapidReconnectCount > 5) {
          print('[Deepgram] Too many rapid reconnects, backing off for 5 seconds');
          await Future.delayed(const Duration(seconds: 5));
          _rapidReconnectCount = 0;
        }
      } else {
        _rapidReconnectCount = 0;
      }
    }
    _lastConnectionAttempt = now;

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
      _webSocket = await WebSocket.connect(
        'wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&channels=1&model=nova-2&language=en-US&punctuate=true&interim_results=true&endpointing=1000&utterance_end_ms=2000&vad_events=true',
        headers: {'Authorization': 'Token $_apiKey'},
      );

      print('[Deepgram] WebSocket CONNECTED!');
      print('\n[Listening... say "Porcupine" + command]\n');

      // Send keepalive pings every 8 seconds to prevent timeout
      // Deepgram expects {"type": "KeepAlive"} JSON message
      _keepAliveTimer?.cancel();
      int keepAliveCount = 0;
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
          try {
            _webSocket!.add('{"type": "KeepAlive"}');
            keepAliveCount++;
            if (keepAliveCount % 4 == 0) {
              print('[Deepgram] Still connected (${keepAliveCount * 8}s)');
            }
          } catch (e) {
            print('[Deepgram] KeepAlive send failed: $e');
          }
        } else {
          print('[Deepgram] KeepAlive FAILED - WebSocket closed');
        }
      });

      // Handle incoming transcripts
      int messageCount = 0;
      _webSocket!.listen(
        (data) {
          messageCount++;
          if (messageCount == 1) {
            print('[Deepgram] First message received from server');
          }
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('[Deepgram] WebSocket ERROR: $error');
          _onError?.call('Connection error');
          _cleanup();
        },
        onDone: () {
          print('[Deepgram] WebSocket CLOSED (received $messageCount messages, closeCode: ${_webSocket?.closeCode}, reason: ${_webSocket?.closeReason})');
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
      int errorCount = 0;
      _audioSubscription = stream.listen(
        (chunk) {
          if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
            _webSocket!.add(chunk);
            chunkCount++;
            if (chunkCount == 1) {
              print('[Audio] First chunk received! (${chunk.length} bytes)');
            }
            // Log every 5 seconds worth of audio (16000 samples/sec, 16 bits, ~32000 bytes/sec)
            if (chunkCount % 500 == 0) {
              print('[Audio] Streaming... ($chunkCount chunks sent)');
            }
            errorCount = 0; // Reset error count on success
          } else {
            errorCount++;
            if (errorCount == 1 || errorCount % 50 == 0) {
              print('[Audio] WebSocket not open! state: ${_webSocket?.readyState}, errors: $errorCount');
            }
          }
        },
        onError: (e) {
          print('[Audio] Stream error: $e');
        },
      );

    } catch (e, stack) {
      print('[Deepgram] EXCEPTION: $e');
      print('[Deepgram] Stack: $stack');
      _isListening = false;
      final errorCallback = _onError;
      final doneCallback = _onDone;
      _onError = null;
      _onDone = null;
      errorCallback?.call('Failed to start: $e');
      doneCallback?.call();
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);

      // Skip non-object messages (arrays, metadata, etc.)
      if (decoded is! Map<String, dynamic>) {
        print('[Deepgram] Non-map message received');
        return;
      }

      final json = decoded;
      final msgType = json['type'] as String?;

      // Log all message types for debugging
      if (msgType != null) {
        print('[Deepgram] Message type: $msgType');
      }

      // Check for transcript - be defensive about types
      final channelRaw = json['channel'];
      if (channelRaw is! Map<String, dynamic>) {
        // Not a transcript message, check for other events
        if (msgType == 'UtteranceEnd') {
          print('[Deepgram] UtteranceEnd event');
          _deliverTranscript();
        }
        return;
      }

      final channel = channelRaw;
      final alternativesRaw = channel['alternatives'];
      if (alternativesRaw is! List || alternativesRaw.isEmpty) {
        return;
      }

      final firstAlt = alternativesRaw[0];
      if (firstAlt is! Map<String, dynamic>) {
        return;
      }

      final transcript = firstAlt['transcript'] as String?;
      final isFinal = json['is_final'] as bool? ?? false;
      final speechFinal = json['speech_final'] as bool? ?? false;

      // Log all transcripts including empty ones
      if (transcript != null && transcript.isNotEmpty) {
        print('[Deepgram] transcript: "$transcript" (isFinal=$isFinal, speechFinal=$speechFinal)');
      }

      if (transcript != null && transcript.isNotEmpty) {
        _lastTranscriptTime = DateTime.now();
        _currentTranscript += (transcript + ' ');

        // Reset silence timer - wait for more speech or deliver after timeout
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 800), () {
          _deliverTranscript();
        });

        // If speech_final, deliver immediately
        if (speechFinal) {
          print('[Deepgram] speech_final - delivering now');
          _deliverTranscript();
        }
      }

    } catch (e, stack) {
      debugPrint('Error parsing message: $e');
      debugPrint('Stack: $stack');
      debugPrint('Data: ${data.toString().substring(0, min(200, data.toString().length))}');
    }
  }

  void _deliverTranscript() {
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

  void _cleanup() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isListening = false;

    // Capture and clear callback before calling to prevent loops
    final doneCallback = _onDone;
    _onDone = null;
    doneCallback?.call();
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
