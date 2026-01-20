import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/providers.dart';
import '../../../../../main.dart' show terminalCommandController;
import '../../../../../core/constants/colors.dart';
import '../../../../../core/constants/strings.dart';
import '../../../agent/domain/email_agent.dart' show AgentContext, EmailAgent;
import '../widgets/email_content_view.dart';
import '../widgets/email_list_item.dart';
import 'pdf_viewer_screen.dart';

/// Wake word variations (Deepgram often mishears "porcupine")
const List<String> kWakeWords = [
  'porcupine',
  'pokepon',
  'pokepun',
  'poke upon',
  'pokey pine',
  'pokey pond',
  'porky pine',
  'pork you pine',
  'okay pine',
  'pope pine',
  'poke a pine',
  'poker pine',
];

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
    _commandController.dispose();
    _commandFocus.dispose();
    _emailScrollController.dispose();
    _inboxScrollController.dispose();
    super.dispose();
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
    ref.read(statusMessageProvider.notifier).state = 'Listening... say "Porcupine" + command';

    // Start continuous streaming - onResult called for each utterance
    print('[EmailScreen] Calling speech.startListening...');
    await speech.startListening(
      onResult: (text) {
        if (text.isEmpty || !mounted) return;

        print('[STT] "$text"');
        final lowerText = text.toLowerCase();

        // Find any wake word variation in the text
        String? command;
        for (final wakeWord in kWakeWords) {
          final idx = lowerText.indexOf(wakeWord);
          if (idx >= 0) {
            command = text.substring(idx + wakeWord.length).trim();
            // Remove punctuation after wake word
            while (command!.isNotEmpty && ',. !'.contains(command[0])) {
              command = command.substring(1).trim();
            }
            break;
          }
        }

        if (command != null && command.isNotEmpty) {
          print('[STT] Command: "$command"');
          // Show transcription in search bar
          _commandController.text = command;
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

    // SCROLL - handle locally for speed (no TTS, PDF viewer also listens)
    if (lowerText.contains('down') || lowerText.contains('up')) {
      final isDown = lowerText.contains('down');
      final isUp = lowerText.contains('up');
      // Scroll the inbox list
      if (_inboxScrollController.hasClients) {
        final current = _inboxScrollController.offset;
        final max = _inboxScrollController.position.maxScrollExtent;
        final scrollAmount = 300.0;
        if (isDown) {
          _inboxScrollController.animateTo(
            (current + scrollAmount).clamp(0, max),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else if (isUp) {
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
    else if (lowerText.contains('close') || lowerText.contains('back')) {
      // PDF viewer handles this via stream, but we stay silent
      response = null;
    }
    // OPEN ATTACHMENT - handle locally (needs Navigator)
    // Match various transcriptions: attachment, attach, atach, atack, pdf
    else if ((lowerText.contains('open') || lowerText.contains('view') || lowerText.contains('download') || lowerText.contains('show')) &&
             (lowerText.contains('attach') || lowerText.contains('atach') || lowerText.contains('atack') || lowerText.contains('pdf'))) {
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
        if (lowerText.contains('pdf')) {
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
    // EVERYTHING ELSE - send to Claude with context
    else {
      final agent = ref.read(emailAgentProvider);

      // Build context from current state
      final context = AgentContext(
        currentEmail: ref.read(selectedEmailProvider),
        selectedIndex: ref.read(selectedEmailIndexProvider),
        emailList: ref.read(currentEmailsProvider),
        currentFolder: ref.read(currentFolderProvider),
      );

      response = await agent.process(text, context: context);
      print('[CMD] Claude response: "$response"');

      // Handle GUI updates from agent (email list, selected email, etc.)
      _syncAgentState(agent);
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

  /// Sync GUI state from agent after tool execution
  void _syncAgentState(EmailAgent agent) {
    final agentEmails = agent.currentEmails;
    if (agentEmails.isNotEmpty) {
      ref.read(currentEmailsProvider.notifier).state = agentEmails;
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
