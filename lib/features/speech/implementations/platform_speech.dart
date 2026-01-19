import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_recognizer.dart';

/// Platform-native speech recognition using speech_to_text package
class PlatformSpeechRecognizer implements SpeechRecognizer {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get isAvailable async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          _isListening = status == 'listening';
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _isListening = false;
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String error)? onError,
    void Function()? onDone,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        onError?.call('Speech recognition not available');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone?.call();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      onSoundLevelChange: null,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  @override
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}
