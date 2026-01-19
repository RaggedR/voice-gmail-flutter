import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
    }
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) return;

    // Print to terminal what TTS is saying
    print('\n----------------------------------------');
    print('[TTS]: $text');
    print('----------------------------------------\n');

    // Stop any current speech
    if (_isSpeaking) {
      await stop();
    }

    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Dispose of resources
  void dispose() {
    _tts.stop();
  }
}
