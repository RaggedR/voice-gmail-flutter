import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';

/// Wake word detection service using Porcupine
class WakeWordService {
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  void Function()? _onWakeWordDetected;

  String get _accessKey => dotenv.env['PICOVOICE_ACCESS_KEY'] ?? '';

  bool get isListening => _isListening;

  /// Initialize with a callback that fires when wake word is detected
  Future<bool> initialize({
    required void Function() onWakeWordDetected,
    BuiltInKeyword keyword = BuiltInKeyword.JARVIS,
  }) async {
    if (_accessKey.isEmpty) {
      debugPrint('Picovoice access key not configured');
      return false;
    }

    _onWakeWordDetected = onWakeWordDetected;

    try {
      _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
        _accessKey,
        [keyword],
        _wakeWordCallback,
        errorCallback: _errorCallback,
      );
      debugPrint('Porcupine initialized with keyword: ${keyword.name}');
      return true;
    } on PorcupineException catch (e) {
      debugPrint('Porcupine initialization error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Wake word initialization error: $e');
      return false;
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    debugPrint('Wake word detected!');
    print('\n*** WAKE WORD DETECTED ***\n');
    _onWakeWordDetected?.call();
  }

  void _errorCallback(PorcupineException e) {
    debugPrint('Porcupine error: ${e.message}');
  }

  /// Start listening for wake word
  Future<void> start() async {
    if (_porcupineManager == null) {
      debugPrint('Porcupine not initialized');
      return;
    }

    if (_isListening) return;

    try {
      await _porcupineManager!.start();
      _isListening = true;
      debugPrint('Wake word detection started');
    } catch (e) {
      debugPrint('Error starting wake word detection: $e');
    }
  }

  /// Stop listening for wake word
  Future<void> stop() async {
    if (_porcupineManager == null || !_isListening) return;

    try {
      await _porcupineManager!.stop();
      _isListening = false;
      debugPrint('Wake word detection stopped');
    } catch (e) {
      debugPrint('Error stopping wake word detection: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await stop();
    _porcupineManager?.delete();
    _porcupineManager = null;
  }
}
