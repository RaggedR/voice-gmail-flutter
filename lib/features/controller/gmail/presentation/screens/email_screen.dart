import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/providers.dart';
import '../../../../../main.dart' show terminalCommandController;
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/strings.dart';
// Note: EmailAgent no longer used - all commands execute directly via Gmail API
import '../../../../voice/domain/voice_normalizer.dart';
import '../../../../voice/domain/correction_learner.dart';
import '../../../../voice/domain/command_matcher.dart';
import '../widgets/email_content_view.dart';
import '../widgets/email_list_item.dart';
import 'pdf_viewer_screen.dart';

/// Wake word
const String kPrimaryWakeWord = 'jarvis';

/// Wake word variations (common STT mishearings)
const List<String> kWakeWords = [
  'jarvis',
  'jarves',
  'jervis',
  'jarvas',
  'jarvus',
  'service',  // common mishearing
  'jar vis',
];

/// Stop word to end conversation mode
const String kStopWord = 'stop';

/// Main email screen with Gmail-style two-panel layout
class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocus = FocusNode();
  final ScrollController _emailScrollController = ScrollController();
  final ScrollController _inboxScrollController = ScrollController();
  StreamSubscription<String>? _terminalSubscription;

  // Prevent duplicate command processing
  String? _lastCommand;
  DateTime? _lastCommandTime;

  // Conversation mode - stays active after wake word for follow-up commands
  bool _conversationModeActive = false;
  Timer? _conversationTimer;
  static const _conversationTimeoutSeconds = 15; // How long to stay active

  // Correction learning - learns from user repetitions/corrections
  final CorrectionLearner _correctionLearner = CorrectionLearner();

  // Command matching - matches transcriptions to known commands
  final CommandMatcher _commandMatcher = CommandMatcher();

  @override
  void initState() {
    super.initState();
    _initializeServices();

    // Listen for terminal commands
    _terminalSubscription = terminalCommandController.stream.listen((command) {
      if (mounted) {
        _processCommand(command);
      }
    });
  }

  @override
  void dispose() {
    _terminalSubscription?.cancel();
    _conversationTimer?.cancel();
    _commandController.dispose();
    _commandFocus.dispose();
    _emailScrollController.dispose();
    _inboxScrollController.dispose();
    super.dispose();
  }

  /// Start or reset conversation mode timer
  void _startConversationMode() {
    _conversationTimer?.cancel();
    _conversationModeActive = true;
    ref.read(statusMessageProvider.notifier).state =
        'Listening... (${_conversationTimeoutSeconds}s)';

    _conversationTimer = Timer(
      Duration(seconds: _conversationTimeoutSeconds),
      () {
        if (mounted) {
          setState(() {
            _conversationModeActive = false;
          });
          ref.read(statusMessageProvider.notifier).state =
              'Say "$kPrimaryWakeWord" to start';
          print('[Conversation] Mode ended - timeout');
        }
      },
    );
    print('[Conversation] Mode started/reset - ${_conversationTimeoutSeconds}s window');
  }

  /// End conversation mode immediately
  void _endConversationMode() {
    _conversationTimer?.cancel();
    _conversationModeActive = false;
    ref.read(statusMessageProvider.notifier).state = 'Say "$kPrimaryWakeWord" to start';
    print('[Conversation] Mode ended manually');
  }

  Future<void> _initializeServices() async {
    print('[EmailScreen] _initializeServices starting...');

    // Initialize TTS
    final tts = ref.read(ttsServiceProvider);
    await tts.initialize();
    print('[EmailScreen] TTS initialized');

    // Initialize speech recognizer
    print('[EmailScreen] Getting speech recognizer...');
    final speech = ref.read(speechRecognizerProvider);
    print('[EmailScreen] Initializing speech recognizer...');
    final available = await speech.initialize();
    print('[EmailScreen] Speech recognizer available: $available');

    if (available) {
      print('[EmailScreen] Calling _startListening...');
      _startListening();
    } else {
      print('[EmailScreen] Speech NOT available, showing text prompt');
      ref.read(statusMessageProvider.notifier).state = 'Type a command below (e.g., "show my inbox")';
    }
  }

  void _startListening() async {
    print('[EmailScreen] _startListening called');
    final speech = ref.read(speechRecognizerProvider);

    ref.read(isListeningProvider.notifier).state = true;
    ref.read(statusMessageProvider.notifier).state = 'Say "$kPrimaryWakeWord" + command';

    // Start continuous streaming - onResult called for each utterance
    print('[EmailScreen] Calling speech.startListening...');
    await speech.startListening(
      onResult: (text) {
        if (text.isEmpty || !mounted) return;

        print('[STT] "$text"');
        final lowerText = text.toLowerCase();

        String? command;

        // Check for stop word to end conversation mode
        // Match "stop", "stop.", "stop!" etc. but not "stop listening" (that's a command)
        final cleanText = lowerText.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (_conversationModeActive && cleanText == kStopWord) {
          print('[STT] Stop word detected');
          _endConversationMode();
          return;
        }

        // If conversation mode is active, treat entire text as command (no wake word needed)
        if (_conversationModeActive) {
          command = text.trim();
          // Remove leading punctuation
          while (command!.isNotEmpty && ',. !'.contains(command[0])) {
            command = command.substring(1).trim();
          }
          print('[STT] Conversation mode - direct command: "$command"');
        } else {
          // Not in conversation mode - need wake word
          int endIdx = -1;

          // 1. Check explicit wake word list first (handles "pokemon", etc.)
          for (final wakeWord in kWakeWords) {
            final idx = lowerText.indexOf(wakeWord);
            if (idx >= 0) {
              endIdx = idx + wakeWord.length;
              print('[STT] Explicit wake word match: "$wakeWord"');
              break;
            }
          }

          // 2. Fall back to fuzzy/phonetic matching for primary wake word
          if (endIdx < 0) {
            final wakeWordMatch = voiceNormalizer.findWakeWord(
              text,
              target: kPrimaryWakeWord,
              cutoff: 55,
            );
            if (wakeWordMatch != null) {
              final (matchedWord, _, matchEndIdx) = wakeWordMatch;
              print('[STT] Fuzzy matched wake word: "$matchedWord"');
              endIdx = matchEndIdx;
            }
          }

          // Extract command after wake word
          if (endIdx >= 0) {
            command = text.substring(endIdx).trim();
            // Remove punctuation after wake word
            while (command!.isNotEmpty && ',. !'.contains(command[0])) {
              command = command.substring(1).trim();
            }
            // Wake word detected - start conversation mode
            _startConversationMode();
          }
        }

        if (command != null && command.isNotEmpty) {
          print('[STT] Command: "$command"');
          // Show transcription in search bar
          _commandController.text = command;

          // Reset conversation mode timer on each command
          if (_conversationModeActive) {
            _startConversationMode();
          }

          // Feed into same stream as text commands from nc localhost 9999
          terminalCommandController.add(command);
        }
      },
      onError: (error) {
        print('[STT] Error: $error');
        if (mounted) {
          ref.read(statusMessageProvider.notifier).state = 'STT error - type command or restart app';
        }
      },
      onDone: () {
        print('[STT] Connection closed');
        if (mounted) {
          ref.read(isListeningProvider.notifier).state = false;
          ref.read(statusMessageProvider.notifier).state = 'STT disconnected - type command or restart app';
        }
      },
    );
  }

  /// Process command - scroll locally, everything else goes to Claude
  Future<void> _processCommand(String text) async {
    if (!mounted) return;

    // Deduplicate - ignore same command within 2 seconds
    final now = DateTime.now();
    if (_lastCommand == text && _lastCommandTime != null) {
      final elapsed = now.difference(_lastCommandTime!).inMilliseconds;
      if (elapsed < 2000) {
        print('[CMD] Ignoring duplicate: "$text" (${elapsed}ms ago)');
        return;
      }
    }
    _lastCommand = text;
    _lastCommandTime = now;

    final stopwatch = Stopwatch()..start();
    print('[CMD] Processing: "$text"');

    final tts = ref.read(ttsServiceProvider);
    final lowerText = text.toLowerCase();

    ref.read(isListeningProvider.notifier).state = false;
    ref.read(recognizedTextProvider.notifier).state = text;
    ref.read(statusMessageProvider.notifier).state = 'Processing...';
    ref.read(isProcessingProvider.notifier).state = true;

    String? response;

    try {

    // Normalize text for number homophones
    final normalizedText = voiceNormalizer.normalize(lowerText);

    // SCROLL - handle locally for speed (no TTS, PDF viewer also listens)
    // Use fuzzy matching for scroll commands: "scrawl down", "scrol up", etc.
    final isScrollDown = voiceNormalizer.containsFuzzyMatch(normalizedText, ['down'], cutoff: 80) ||
                         normalizedText.contains('down');
    final isScrollUp = voiceNormalizer.containsFuzzyMatch(normalizedText, ['up'], cutoff: 80) ||
                       normalizedText.contains('up');
    final hasScrollWord = voiceNormalizer.containsFuzzyMatch(normalizedText, ['scroll'], cutoff: 70) ||
                          normalizedText.contains('scroll');

    if (hasScrollWord && (isScrollDown || isScrollUp)) {
      // Scroll the inbox list
      if (_inboxScrollController.hasClients) {
        final current = _inboxScrollController.offset;
        final max = _inboxScrollController.position.maxScrollExtent;
        final scrollAmount = 300.0;
        if (isScrollDown) {
          _inboxScrollController.animateTo(
            (current + scrollAmount).clamp(0, max),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else if (isScrollUp) {
          _inboxScrollController.animateTo(
            (current - scrollAmount).clamp(0, max),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
      response = null; // Silent - no TTS for scroll
    }
    // CLOSE - handle locally for PDF viewer
    else if (voiceNormalizer.containsFuzzyMatch(normalizedText, ['close', 'back'], cutoff: 75) ||
             normalizedText.contains('close') || normalizedText.contains('back')) {
      // PDF viewer handles this via stream, but we stay silent
      response = null;
    }
    // OPEN ATTACHMENT - handle locally (needs Navigator)
    // Use fuzzy matching for attachment commands: "atach", "attatch", etc.
    else if ((voiceNormalizer.containsFuzzyMatch(normalizedText, ['open', 'view', 'download', 'show'], cutoff: 75) ||
              normalizedText.contains('open') || normalizedText.contains('view') ||
              normalizedText.contains('download') || normalizedText.contains('show')) &&
             (voiceNormalizer.containsFuzzyMatch(normalizedText, ['attachment', 'pdf'], cutoff: 70) ||
              normalizedText.contains('attach') || normalizedText.contains('pdf'))) {
      print('[CMD] Matched attachment command');
      final gmail = ref.read(gmailRepositoryProvider);
      final selectedEmail = ref.read(selectedEmailProvider);
      print('[CMD] Selected email: ${selectedEmail?.subject}, attachments: ${selectedEmail?.attachments.length ?? 0}');
      if (selectedEmail == null) {
        response = 'Select an email first.';
      } else if (selectedEmail.attachments.isEmpty) {
        response = 'No attachments.';
      } else {
        // Find which attachment to open (default to first, or first PDF if mentioned)
        int attachmentIndex = 0;
        if (normalizedText.contains('pdf')) {
          final pdfIdx = selectedEmail.attachments.indexWhere((a) => a.mimeType.contains('pdf'));
          if (pdfIdx >= 0) attachmentIndex = pdfIdx;
        }

        final attachment = selectedEmail.attachments[attachmentIndex];
        ref.read(statusMessageProvider.notifier).state = 'Downloading ${attachment.filename}...';

        final filePath = await gmail.downloadAttachment(
          selectedEmail.id,
          attachment.id,
          attachment.filename,
        );

        if (filePath != null) {
          if (attachment.mimeType.contains('pdf')) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PdfViewerScreen(
                    filePath: filePath,
                    filename: attachment.filename,
                  ),
                ),
              );
            }
          } else {
            await Process.run('open', [filePath]);
          }
        }
        response = null; // Silent - action is obvious
      }
    }
    // TRY COMMAND MATCHER FIRST - fast local matching
    else {
      final match = _commandMatcher.match(normalizedText);

      if (match != null && match.confidence >= 50) {
        // Match found - execute directly without Claude
        print('[CMD] Matched: ${match.command} (${match.confidence}%) args=${match.args}');
        response = await _executeMatchedCommand(match);
        _correctionLearner.markLastCommandSuccessful();
      } else {
        // No match or very low confidence - don't use Claude, just report
        if (match != null) {
          print('[CMD] Very low confidence match: ${match.command} (${match.confidence}%) - ignoring');
        } else {
          print('[CMD] No match found');
        }
        response = 'Command not recognized. Try: show inbox, delete, archive, next, previous, scroll down.';
      }
    }

    ref.read(isProcessingProvider.notifier).state = false;
    ref.read(statusMessageProvider.notifier).state = (response == null || response.isEmpty) ? 'Listening...' : response;
    print('[CMD] Done in ${stopwatch.elapsedMilliseconds}ms');

    // Pause mic, speak, then resume mic (prevent feedback loop)
    if (response != null && response.isNotEmpty) {
      final speech = ref.read(speechRecognizerProvider);
      await speech.stopListening();
      if (mounted) {
        ref.read(statusMessageProvider.notifier).state = 'Speaking...';
      }
      await tts.speak(response);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ref.read(statusMessageProvider.notifier).state = 'Listening...';
        _startListening();
      }
    } else {
      // No TTS response - update status and keep listening
      if (mounted) {
        ref.read(statusMessageProvider.notifier).state = 'Listening...';
      }
    }

    } catch (e, stack) {
      print('[CMD] Error processing command: $e');
      print('[CMD] Stack: $stack');
      if (mounted) {
        ref.read(isProcessingProvider.notifier).state = false;
        ref.read(statusMessageProvider.notifier).state = 'Error: ${e.toString().split('\n').first}';
        // Restart listening after error
        _startListening();
      }
    }
  }

  /// Execute a matched command directly (no Claude API calls)
  Future<String?> _executeMatchedCommand(CommandMatch match) async {
    final gmail = ref.read(gmailRepositoryProvider);
    final emails = ref.read(currentEmailsProvider);
    final selectedEmail = ref.read(selectedEmailProvider);
    final selectedIndex = ref.read(selectedEmailIndexProvider);

    switch (match.command) {
      // === INBOX NAVIGATION (no Claude needed) ===
      case 'show_inbox':
        final inboxEmails = await gmail.listEmails(query: 'in:inbox', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = inboxEmails;
        ref.read(currentFolderProvider.notifier).state = 'inbox';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${inboxEmails.length} emails.';

      case 'show_unread':
        final unreadEmails = await gmail.listEmails(query: 'is:unread in:inbox', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = unreadEmails;
        ref.read(currentFolderProvider.notifier).state = 'unread';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${unreadEmails.length} unread.';

      case 'show_sent':
        final sentEmails = await gmail.listEmails(query: 'in:sent', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = sentEmails;
        ref.read(currentFolderProvider.notifier).state = 'sent';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${sentEmails.length} sent.';

      case 'show_drafts':
        final draftEmails = await gmail.listEmails(query: 'in:drafts', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = draftEmails;
        ref.read(currentFolderProvider.notifier).state = 'drafts';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${draftEmails.length} drafts.';

      case 'show_starred':
        final starredEmails = await gmail.listEmails(query: 'is:starred', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = starredEmails;
        ref.read(currentFolderProvider.notifier).state = 'starred';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${starredEmails.length} starred.';

      case 'show_spam':
        final spamEmails = await gmail.listEmails(query: 'in:spam', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = spamEmails;
        ref.read(currentFolderProvider.notifier).state = 'spam';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${spamEmails.length} spam.';

      case 'show_trash':
        final trashEmails = await gmail.listEmails(query: 'in:trash', maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = trashEmails;
        ref.read(currentFolderProvider.notifier).state = 'trash';
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return '${trashEmails.length} trash.';

      case 'check_inbox':
        final unread = await gmail.getUnreadCount();
        final total = await gmail.getInboxCount();
        return '$unread unread of $total.';

      case 'refresh':
        final currentFolder = ref.read(currentFolderProvider);
        final queryMap = {
          'inbox': 'in:inbox',
          'sent': 'in:sent',
          'drafts': 'in:drafts',
          'starred': 'is:starred',
          'spam': 'in:spam',
          'trash': 'in:trash',
          'unread': 'is:unread in:inbox'
        };
        final query = queryMap[currentFolder] ?? 'in:inbox';
        final refreshedEmails = await gmail.listEmails(query: query, maxResults: 20);
        ref.read(currentEmailsProvider.notifier).state = refreshedEmails;
        return 'Refreshed. ${refreshedEmails.length} emails.';

      // === EMAIL SELECTION ===
      case 'open_email':
        final number = match.args['number'] as int?;
        if (number != null && number > 0 && number <= emails.length) {
          final email = emails[number - 1];
          final fullEmail = await gmail.getEmail(email.id, includeBody: true);
          if (fullEmail != null) {
            ref.read(selectedEmailProvider.notifier).state = fullEmail;
            ref.read(selectedEmailIndexProvider.notifier).state = number - 1;
            await gmail.markAsRead(email.id);
            return null;
          }
        }
        return 'Invalid email number.';

      case 'next_email':
        if (emails.isEmpty) return 'No emails.';
        final nextIdx = (selectedIndex ?? -1) + 1;
        if (nextIdx >= emails.length) return 'Last email.';
        final email = emails[nextIdx];
        final fullEmail = await gmail.getEmail(email.id, includeBody: true);
        if (fullEmail != null) {
          ref.read(selectedEmailProvider.notifier).state = fullEmail;
          ref.read(selectedEmailIndexProvider.notifier).state = nextIdx;
          await gmail.markAsRead(email.id);
        }
        return null;

      case 'previous_email':
        if (emails.isEmpty) return 'No emails.';
        final prevIdx = (selectedIndex ?? 1) - 1;
        if (prevIdx < 0) return 'First email.';
        final email = emails[prevIdx];
        final fullEmail = await gmail.getEmail(email.id, includeBody: true);
        if (fullEmail != null) {
          ref.read(selectedEmailProvider.notifier).state = fullEmail;
          ref.read(selectedEmailIndexProvider.notifier).state = prevIdx;
          await gmail.markAsRead(email.id);
        }
        return null;

      case 'first_email':
        if (emails.isEmpty) return 'No emails.';
        final email = emails[0];
        final fullEmail = await gmail.getEmail(email.id, includeBody: true);
        if (fullEmail != null) {
          ref.read(selectedEmailProvider.notifier).state = fullEmail;
          ref.read(selectedEmailIndexProvider.notifier).state = 0;
          await gmail.markAsRead(email.id);
        }
        return null;

      case 'last_email':
        if (emails.isEmpty) return 'No emails.';
        final lastIdx = emails.length - 1;
        final email = emails[lastIdx];
        final fullEmail = await gmail.getEmail(email.id, includeBody: true);
        if (fullEmail != null) {
          ref.read(selectedEmailProvider.notifier).state = fullEmail;
          ref.read(selectedEmailIndexProvider.notifier).state = lastIdx;
          await gmail.markAsRead(email.id);
        }
        return null;

      // === EMAIL ACTIONS ===
      case 'delete':
        if (selectedEmail == null || selectedIndex == null) return 'No email selected.';
        await gmail.deleteEmail(selectedEmail.id);
        final newEmails = List.of(emails)..removeAt(selectedIndex);
        ref.read(currentEmailsProvider.notifier).state = newEmails;
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return 'Deleted.';

      case 'delete_email':
        final number = match.args['number'] as int?;
        if (number == null || number < 1 || number > emails.length) return 'Invalid number.';
        final email = emails[number - 1];
        await gmail.deleteEmail(email.id);
        final newEmails = List.of(emails)..removeAt(number - 1);
        ref.read(currentEmailsProvider.notifier).state = newEmails;
        if (selectedIndex == number - 1) {
          ref.read(selectedEmailProvider.notifier).state = null;
          ref.read(selectedEmailIndexProvider.notifier).state = -1;
        }
        return 'Deleted.';

      case 'archive':
        if (selectedEmail == null || selectedIndex == null) return 'No email selected.';
        await gmail.archiveEmail(selectedEmail.id);
        final newEmails = List.of(emails)..removeAt(selectedIndex);
        ref.read(currentEmailsProvider.notifier).state = newEmails;
        ref.read(selectedEmailProvider.notifier).state = null;
        ref.read(selectedEmailIndexProvider.notifier).state = -1;
        return 'Archived.';

      case 'archive_email':
        final number = match.args['number'] as int?;
        if (number == null || number < 1 || number > emails.length) return 'Invalid number.';
        final email = emails[number - 1];
        await gmail.archiveEmail(email.id);
        final newEmails = List.of(emails)..removeAt(number - 1);
        ref.read(currentEmailsProvider.notifier).state = newEmails;
        if (selectedIndex == number - 1) {
          ref.read(selectedEmailProvider.notifier).state = null;
          ref.read(selectedEmailIndexProvider.notifier).state = -1;
        }
        return 'Archived.';

      case 'star':
        if (selectedEmail == null) return 'No email selected.';
        await gmail.applyLabel(selectedEmail.id, 'STARRED');
        return 'Starred.';

      case 'unstar':
        if (selectedEmail == null) return 'No email selected.';
        await gmail.removeLabel(selectedEmail.id, 'STARRED');
        return 'Unstarred.';

      // === LABELS ===
      case 'label':
        if (selectedEmail == null) return 'No email selected.';
        final labelName = match.args['text'] as String?;
        if (labelName == null || labelName.isEmpty) return 'Which label?';
        await gmail.applyLabel(selectedEmail.id, labelName);
        return 'Labeled $labelName.';

      case 'remove_label':
        if (selectedEmail == null) return 'No email selected.';
        final labelName = match.args['text'] as String?;
        if (labelName == null || labelName.isEmpty) return 'Which label?';
        await gmail.removeLabel(selectedEmail.id, labelName);
        return 'Removed $labelName.';

      case 'show_labels':
        final labels = await gmail.listLabels();
        final userLabels = labels.where((l) => !l.id.startsWith('CATEGORY_')).toList();
        return '${userLabels.length} labels: ${userLabels.take(5).map((l) => l.name).join(", ")}...';

      // === SEARCH ===
      case 'search':
        final query = match.args['text'] as String?;
        if (query == null || query.isEmpty) return 'Search for what?';
        final results = await gmail.searchEmails(query);
        ref.read(currentEmailsProvider.notifier).state = results;
        return 'Found ${results.length}.';

      case 'from':
        final name = match.args['text'] as String?;
        if (name == null || name.isEmpty) return 'From who?';
        final results = await gmail.searchEmails('from:$name');
        ref.read(currentEmailsProvider.notifier).state = results;
        return 'Found ${results.length} from $name.';

      // === ATTACHMENTS ===
      case 'open_attachment':
        if (selectedEmail == null) return 'No email selected.';
        if (selectedEmail.attachments.isEmpty) return 'No attachments.';
        final idx = (match.args['number'] as int? ?? 1) - 1;
        if (idx < 0 || idx >= selectedEmail.attachments.length) return 'Invalid attachment.';
        await _openAttachmentByIndex(idx + 1);
        return null;

      case 'open_pdf':
        if (selectedEmail == null) return 'No email selected.';
        final pdfIdx = selectedEmail.attachments.indexWhere((a) => a.mimeType.contains('pdf'));
        if (pdfIdx < 0) return 'No PDF attachment.';
        await _openAttachmentByIndex(pdfIdx + 1);
        return null;

      // === PDF VIEWER (handled by PDF viewer itself via stream) ===
      case 'scroll_down':
      case 'scroll_up':
      case 'next_page':
      case 'previous_page':
      case 'first_page':
      case 'last_page':
      case 'zoom_in':
      case 'zoom_out':
      case 'close':
        // These are handled by PDF viewer listening to the command stream
        return null;

      case 'page':
        // Page number command - PDF viewer handles via stream
        return null;

      // === PAGINATION ===
      case 'more':
        // Load more emails (pagination - not yet fully implemented)
        return 'More is not implemented yet.';

      // === SYSTEM ===
      case 'stop':
        _conversationModeActive = false;
        _conversationTimer?.cancel();
        return 'Stopped.';

      case 'help':
        return 'Navigation: show inbox, unread, sent, starred. Reading: next, previous, email [number]. Actions: delete, archive, star. Attachments: open pdf. Say "list commands" for full list.';

      case 'list_commands':
        // Full list of all available commands
        final allCommands = '''
NAVIGATION: show inbox, show unread, show sent, show drafts, show starred, show spam, show trash, refresh, check inbox

READING: email [1-9], next, previous, first, last

ACTIONS: delete, archive, star, unstar, mark read, mark unread

LABELS: label [name], remove label [name], show labels

SEARCH: search [query], from [name]

ATTACHMENTS: open attachment, open pdf

COMPOSING: compose, reply, reply all, forward, send, cancel

PDF: scroll up, scroll down, next page, previous page, zoom in, zoom out, close

SYSTEM: help, stop
''';
        print(allCommands);
        return 'Commands printed to console. Navigation: show inbox/sent/starred. Read: next, previous, email 1. Actions: delete, archive.';

      default:
        // Unknown command - let Claude handle it
        return null;
    }
  }

  void _submitCommand() {
    final text = _commandController.text.trim();
    if (text.isNotEmpty) {
      _commandController.clear();
      _processCommand(text);
    }
  }

  Widget _buildContactsView(List<Contact> contacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: GmailColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.contacts, color: GmailColors.primary),
              const SizedBox(width: 12),
              Text(
                'Contacts (${contacts.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GmailColors.text,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(displayContactsProvider.notifier).state = null;
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        // Contacts list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: GmailColors.primary,
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(contact.email),
                  trailing: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: GmailColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectEmail(int index) async {
    ref.read(selectedEmailIndexProvider.notifier).state = index;

    final emails = ref.read(currentEmailsProvider);
    if (index >= 0 && index < emails.length) {
      final gmail = ref.read(gmailRepositoryProvider);
      final fullEmail = await gmail.getEmail(emails[index].id, includeBody: true);
      if (fullEmail != null) {
        ref.read(selectedEmailProvider.notifier).state = fullEmail;
        final updatedEmails = [...emails];
        updatedEmails[index] = fullEmail;
        ref.read(currentEmailsProvider.notifier).state = updatedEmails;
      }
    }
  }

  /// Open attachment by index (1-based)
  Future<void> _openAttachmentByIndex(int attachmentIndex) async {
    final gmail = ref.read(gmailRepositoryProvider);
    final selectedEmail = ref.read(selectedEmailProvider);
    final tts = ref.read(ttsServiceProvider);

    if (selectedEmail == null) {
      await tts.speak('Select an email first.');
      return;
    }
    if (selectedEmail.attachments.isEmpty) {
      await tts.speak('No attachments.');
      return;
    }

    // Convert 1-based to 0-based index
    final idx = attachmentIndex - 1;
    if (idx < 0 || idx >= selectedEmail.attachments.length) {
      await tts.speak('Invalid attachment number.');
      return;
    }

    final attachment = selectedEmail.attachments[idx];
    ref.read(statusMessageProvider.notifier).state = 'Downloading ${attachment.filename}...';

    final filePath = await gmail.downloadAttachment(
      selectedEmail.id,
      attachment.id,
      attachment.filename,
    );

    if (filePath != null) {
      if (attachment.mimeType.contains('pdf')) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                filePath: filePath,
                filename: attachment.filename,
              ),
            ),
          );
        }
      } else {
        await Process.run('open', [filePath]);
      }
    }

    ref.read(statusMessageProvider.notifier).state = 'Listening...';
  }

  @override
  Widget build(BuildContext context) {
    final emails = ref.watch(currentEmailsProvider);
    final selectedIndex = ref.watch(selectedEmailIndexProvider);
    final selectedEmail = ref.watch(selectedEmailProvider);
    final statusMessage = ref.watch(statusMessageProvider);
    final isListening = ref.watch(isListeningProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final currentFolder = ref.watch(currentFolderProvider);
    final displayContacts = ref.watch(displayContactsProvider);

    // Listen for attachment open requests from Claude's tool
    ref.listen<int?>(openAttachmentRequestProvider, (previous, next) {
      if (next != null) {
        // Reset the provider immediately to prevent re-triggering
        ref.read(openAttachmentRequestProvider.notifier).state = null;
        _openAttachmentByIndex(next);
      }
    });

    return Scaffold(
      backgroundColor: GmailColors.background,
      body: Column(
        children: [
          // Header bar with command input
          Container(
            height: 64,
            color: GmailColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Gmail',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: GmailColors.primary,
                  ),
                ),
                const Text(
                  ' Voice',
                  style: TextStyle(
                    fontSize: 22,
                    color: GmailColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 32),
                // Command input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: GmailColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _commandController,
                      focusNode: _commandFocus,
                      decoration: const InputDecoration(
                        hintText: 'Type a command (e.g., "show my inbox", "read email 1")',
                        hintStyle: TextStyle(
                          color: GmailColors.textLight,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: GmailColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (_) => _submitCommand(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(GmailColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Left panel - Email list
                  Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: GmailColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: GmailColors.border),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${currentFolder.substring(0, 1).toUpperCase()}${currentFolder.substring(1)} (${emails.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: GmailColors.text,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: emails.isEmpty
                              ? const Center(
                                  child: Text(
                                    AppStrings.noEmails,
                                    style: TextStyle(
                                      color: GmailColors.textSecondary,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  controller: _inboxScrollController,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _inboxScrollController,
                                    itemCount: emails.length,
                                    itemBuilder: (context, index) {
                                      return EmailListItem(
                                        email: emails[index],
                                        index: index + 1,
                                        isSelected: index == selectedIndex,
                                        onTap: () => _selectEmail(index),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right panel - Email content or Contacts
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: GmailColors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: displayContacts != null
                          ? _buildContactsView(displayContacts)
                          : EmailContentView(
                              email: selectedEmail ?? (selectedIndex >= 0 && selectedIndex < emails.length ? emails[selectedIndex] : null),
                              scrollController: _emailScrollController,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Status bar
          Container(
            height: 32,
            color: GmailColors.border,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isListening ? Icons.mic : Icons.keyboard,
                  size: 14,
                  color: isListening ? GmailColors.primary : GmailColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GmailColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
