/// Abstract interface for speech recognition
abstract class SpeechRecognizer {
  /// Whether the recognizer is currently listening
  bool get isListening;

  /// Whether speech recognition is available
  Future<bool> get isAvailable;

  /// Initialize the recognizer
  Future<bool> initialize();

  /// Start listening for speech
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String error)? onError,
    void Function()? onDone,
  });

  /// Stop listening
  Future<void> stopListening();

  /// Dispose of resources
  void dispose();
}
