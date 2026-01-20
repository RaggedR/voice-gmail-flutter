import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/controller/addressbook/data/addressbook.dart';
export '../features/controller/addressbook/data/addressbook.dart' show Contact;
import '../features/controller/agent/domain/email_agent.dart';
import '../features/controller/gmail/data/email_model.dart';
import '../features/controller/gmail/data/gmail_auth.dart';
import '../features/controller/gmail/data/gmail_repository.dart';
import '../features/voice/domain/speech_recognizer.dart';
import '../features/voice/domain/wake_word_service.dart';
import '../features/voice/implementations/deepgram_speech.dart';
import '../features/voice/implementations/platform_speech.dart';
import '../features/tts/tts_service.dart';

// ============================================
// Gmail Providers
// ============================================

/// Gmail authentication provider
final gmailAuthProvider = Provider<GmailAuth>((ref) {
  return GmailAuth();
});

/// Gmail repository provider
final gmailRepositoryProvider = Provider<GmailRepository>((ref) {
  final auth = ref.watch(gmailAuthProvider);
  return GmailRepository(auth);
});

/// Authentication state provider
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(gmailAuthProvider);
  final token = await auth.getAccessToken();
  return token != null;
});

// ============================================
// Email State Providers
// ============================================

/// Current emails list state
final currentEmailsProvider = StateProvider<List<Email>>((ref) => []);

/// Selected email index
final selectedEmailIndexProvider = StateProvider<int>((ref) => -1);

/// Currently displayed email (with full content)
final selectedEmailProvider = StateProvider<Email?>((ref) => null);

/// Current folder/label
final currentFolderProvider = StateProvider<String>((ref) => 'inbox');

/// Loading state
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Status message
final statusMessageProvider = StateProvider<String>((ref) => 'Listening for voice commands...');

// ============================================
// Speech Providers
// ============================================

/// Speech recognizer provider
final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final engine = dotenv.env['STT_ENGINE'] ?? 'platform';
  if (engine == 'deepgram') {
    return DeepgramSpeechRecognizer();
  }
  return PlatformSpeechRecognizer();
});

/// Whether speech recognition is listening
final isListeningProvider = StateProvider<bool>((ref) => false);

/// Last recognized text
final recognizedTextProvider = StateProvider<String>((ref) => '');

/// Wake word service provider
final wakeWordServiceProvider = Provider<WakeWordService>((ref) {
  final service = WakeWordService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Whether wake word is enabled
final wakeWordEnabledProvider = StateProvider<bool>((ref) {
  final key = dotenv.env['PICOVOICE_ACCESS_KEY'] ?? '';
  return key.isNotEmpty;
});

/// Whether waiting for wake word
final awaitingWakeWordProvider = StateProvider<bool>((ref) => true);

// ============================================
// TTS Providers
// ============================================

/// TTS service provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Whether TTS is currently speaking
final isSpeakingProvider = StateProvider<bool>((ref) => false);

// ============================================
// Agent Providers
// ============================================

/// Email agent provider
final emailAgentProvider = Provider<EmailAgent>((ref) {
  final gmail = ref.watch(gmailRepositoryProvider);

  return EmailAgent(gmail, onGuiUpdate: (action, data) {
    switch (action) {
      case 'updateEmailList':
        final emails = data as List<Email>;
        ref.read(currentEmailsProvider.notifier).state = emails;
        if (emails.isNotEmpty) {
          ref.read(selectedEmailIndexProvider.notifier).state = 0;
        }
        break;
      case 'showEmail':
        final map = data as Map<String, dynamic>;
        final email = map['email'] as Email;
        final number = map['number'] as int;
        ref.read(selectedEmailProvider.notifier).state = email;
        ref.read(selectedEmailIndexProvider.notifier).state = number - 1;
        break;
      case 'setStatus':
        ref.read(statusMessageProvider.notifier).state = data as String;
        break;
      case 'showContacts':
        final contacts = data as List<Contact>;
        ref.read(displayContactsProvider.notifier).state = contacts;
        break;
      case 'openAttachment':
        final map = data as Map<String, dynamic>;
        final index = map['index'] as int;
        ref.read(openAttachmentRequestProvider.notifier).state = index;
        break;
    }
  });
});

/// Agent processing state
final isProcessingProvider = StateProvider<bool>((ref) => false);

// ============================================
// Addressbook Providers
// ============================================

/// Addressbook provider
final addressBookProvider = Provider<AddressBook>((ref) {
  return AddressBook();
});

/// Contacts to display (when list_contacts is called)
final displayContactsProvider = StateProvider<List<Contact>?>((ref) => null);

/// Attachment open request (index to open, null if none)
final openAttachmentRequestProvider = StateProvider<int?>((ref) => null);
