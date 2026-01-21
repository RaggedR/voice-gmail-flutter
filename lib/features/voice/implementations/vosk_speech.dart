import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/speech_recognizer.dart';

/// Vosk speech recognition via local Python server.
///
/// Connects to a Vosk WebSocket server running locally that uses
/// constrained vocabulary for accurate command recognition.
///
/// Start the server with: python vosk_server/server.py
class VoskSpeechRecognizer implements SpeechRecognizer {
  final AudioRecorder _recorder = AudioRecorder();
  WebSocket? _webSocket;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isListening = false;
  bool _isInitialized = false;

  // Server configuration
  final String _host;
  final int _port;

  // Callbacks
  void Function(String text)? _onResult;
  void Function(String error)? _onError;
  void Function()? _onDone;

  // Reconnection protection
  DateTime? _lastConnectionAttempt;
  int _rapidReconnectCount = 0;

  VoskSpeechRecognizer({
    String host = 'localhost',
    int port = 8765,
  })  : _host = host,
        _port = port;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get isAvailable async {
    // Check if server is reachable
    try {
      final socket = await WebSocket.connect('ws://$_host:$_port')
          .timeout(const Duration(seconds: 2));
      await socket.close();
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[Vosk] Server not available at ws://$_host:$_port');
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    print('[Vosk] initialize() called, _isInitialized=$_isInitialized');
    if (_isInitialized) return true;

    final hasPermission = await _recorder.hasPermission();
    print('[Vosk] Microphone permission: $hasPermission');
    if (!hasPermission) {
      print('[Vosk] ERROR: No microphone permission');
      return false;
    }

    // Check server availability
    try {
      final socket = await WebSocket.connect('ws://$_host:$_port')
          .timeout(const Duration(seconds: 3));
      await socket.close();
      print('[Vosk] Server available at ws://$_host:$_port');
    } catch (e) {
      print('[Vosk] ERROR: Server not available - start with: python vosk_server/server.py');
      return false;
    }

    _isInitialized = true;
    print('[Vosk] Initialized successfully');
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String error)? onError,
    void Function()? onDone,
  }) async {
    print('[Vosk] startListening called');

    // Protect against rapid reconnection loops
    final now = DateTime.now();
    if (_lastConnectionAttempt != null) {
      final elapsed = now.difference(_lastConnectionAttempt!).inMilliseconds;
      if (elapsed < 1000) {
        _rapidReconnectCount++;
        if (_rapidReconnectCount > 5) {
          print('[Vosk] Too many rapid reconnects, backing off for 5 seconds');
          await Future.delayed(const Duration(seconds: 5));
          _rapidReconnectCount = 0;
        }
      } else {
        _rapidReconnectCount = 0;
      }
    }
    _lastConnectionAttempt = now;

    if (!_isInitialized) {
      print('[Vosk] Not initialized, initializing now...');
      final success = await initialize();
      if (!success) {
        print('[Vosk] Initialization FAILED');
        onError?.call('Vosk server not available. Start with: python vosk_server/server.py');
        onDone?.call();
        return;
      }
      print('[Vosk] Initialization successful');
    }

    if (_isListening) {
      print('[Vosk] Already listening, stopping first...');
      await stopListening();
    }

    _onResult = onResult;
    _onError = onError;
    _onDone = onDone;
    _isListening = true;

    try {
      print('[Vosk] Connecting to WebSocket...');
      _webSocket = await WebSocket.connect('ws://$_host:$_port');

      print('[Vosk] WebSocket CONNECTED!');
      print('\n[Vosk] Listening with constrained vocabulary...\n');

      // Handle incoming transcripts
      int messageCount = 0;
      _webSocket!.listen(
        (data) {
          messageCount++;
          if (messageCount == 1) {
            print('[Vosk] First message received from server');
          }
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('[Vosk] WebSocket ERROR: $error');
          _onError?.call('Connection error');
          _cleanup();
        },
        onDone: () {
          print('[Vosk] WebSocket CLOSED (received $messageCount messages)');
          _cleanup();
        },
      );

      // Start streaming audio to WebSocket
      print('[Vosk] Starting audio stream...');
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      print('[Vosk] Audio stream started!');

      int chunkCount = 0;
      _audioSubscription = stream.listen(
        (chunk) {
          if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
            _webSocket!.add(chunk);
            chunkCount++;
            if (chunkCount == 1) {
              print('[Vosk] First audio chunk sent (${chunk.length} bytes)');
            }
          }
        },
        onError: (e) {
          print('[Vosk] Audio stream error: $e');
        },
      );

    } catch (e, stack) {
      print('[Vosk] EXCEPTION: $e');
      print('[Vosk] Stack: $stack');
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
      print('[Vosk] Raw message: $data');
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final text = json['text'] as String? ?? '';

      print('[Vosk] Parsed: type=$type, text="$text"');

      if (type == 'final' && text.isNotEmpty) {
        print('[Vosk] Final result: "$text"');
        print('\n========================================');
        print('YOU SAID: "$text"');
        print('========================================\n');
        _onResult?.call(text);
      } else if (type == 'partial' && text.isNotEmpty) {
        print('[Vosk] Partial: "$text"');
      }

    } catch (e, stack) {
      print('[Vosk] Error parsing message: $e');
      print('[Vosk] Stack: $stack');
      print('[Vosk] Raw data: $data');
    }
  }

  void _cleanup() {
    _isListening = false;

    // Capture and clear callback before calling to prevent loops
    final doneCallback = _onDone;
    _onDone = null;
    doneCallback?.call();
  }

  @override
  Future<void> stopListening() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // Send EOF to get final result
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      try {
        _webSocket!.add('{"type": "eof"}');
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Ignore
      }
    }

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
