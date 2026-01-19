import 'package:flutter/foundation.dart';

import '../../addressbook/data/addressbook.dart';
import '../../gmail/data/email_model.dart';
import '../../gmail/data/gmail_repository.dart';
import '../../gmail/tools/gmail_tools.dart';
import '../../window/platform/window_executor.dart';
import '../../window/tools/window_tools.dart';
import '../data/anthropic_client.dart';

/// System prompt for the voice agent
const String kSystemPrompt = '''You are a voice assistant for a user who cannot use their hands but CAN SEE THE SCREEN.

CRITICAL: The user can read perfectly fine. NEVER read email content, subjects, or bodies aloud.
Your job is to CONTROL the app, not narrate it.

CONTEXT:
{context}

RESPONSE STYLE:
- Ultra brief confirmations only: "Done", "Showing inbox", "Archived", "3 emails"
- NEVER read email content - the user can see it
- NEVER summarize emails unless explicitly asked to "read aloud" or "summarize"
- Just confirm actions completed

ANSWER BRIEFLY FROM CONTEXT:
- "Who sent this?" → Just the name: "John Smith"
- "When was this sent?" → Just the date: "Yesterday at 3pm"
- "Any attachments?" → "Yes, 2 files" or "No"

USE TOOLS FOR:
- "Show inbox" → list_emails
- "Find emails from John" → search_emails
- "Archive/delete this" → archive_email/delete_email
- "Reply saying..." → reply_to_email
- "Send email to..." → send_email

Window control: "Focus Safari", "close window", "fullscreen"
''';

/// Callback for GUI updates
typedef GuiCallback = void Function(String action, dynamic data);

/// Context passed to the agent for natural language understanding
class AgentContext {
  final Email? currentEmail;
  final int? selectedIndex;
  final List<Email> emailList;
  final String currentFolder;

  AgentContext({
    this.currentEmail,
    this.selectedIndex,
    required this.emailList,
    required this.currentFolder,
  });

  String toPromptString() {
    final buffer = StringBuffer();

    buffer.writeln('Current folder: $currentFolder');
    buffer.writeln('Emails in list: ${emailList.length}');

    if (currentEmail != null && selectedIndex != null) {
      buffer.writeln('\nCurrently viewing email ${selectedIndex! + 1}:');
      buffer.writeln('  From: ${currentEmail!.sender}');
      if (currentEmail!.to != null) {
        buffer.writeln('  To: ${currentEmail!.to}');
      }
      buffer.writeln('  Subject: ${currentEmail!.subject}');
      buffer.writeln('  Date: ${currentEmail!.date ?? "unknown"}');
      buffer.writeln('  Attachments: ${currentEmail!.attachments.length}');
      if (currentEmail!.attachments.isNotEmpty) {
        buffer.writeln('  Attachment names: ${currentEmail!.attachments.map((a) => a.filename).join(", ")}');
      }
      if (currentEmail!.body != null && currentEmail!.body!.isNotEmpty) {
        // Include first 200 chars of body (keep context small for speed)
        final bodyPreview = currentEmail!.body!.length > 200
            ? '${currentEmail!.body!.substring(0, 200)}...'
            : currentEmail!.body!;
        buffer.writeln('  Body: $bodyPreview');
      }
    } else {
      buffer.writeln('\nNo email currently selected.');
    }

    if (emailList.isNotEmpty) {
      buffer.writeln('\nEmail list summary:');
      for (var i = 0; i < emailList.length && i < 10; i++) {
        final e = emailList[i];
        buffer.writeln('  ${i + 1}. ${_extractName(e.sender)}: ${e.subject}');
      }
    }

    return buffer.toString();
  }

  static String _extractName(String sender) {
    if (sender.contains('<')) {
      return sender.split('<')[0].trim().replaceAll('"', '');
    }
    return sender.split('@')[0];
  }
}

/// Natural language email agent powered by Claude
class EmailAgent {
  final AnthropicClient _client = AnthropicClient();
  final GmailRepository _gmail;
  final AddressBook _addressBook = AddressBook();
  final WindowExecutor _windowExecutor = WindowExecutor();
  final GuiCallback? _onGuiUpdate;

  List<Email> _currentEmails = [];
  List<Map<String, dynamic>> _conversationHistory = [];
  String _currentSystemPrompt = kSystemPrompt;

  EmailAgent(this._gmail, {GuiCallback? onGuiUpdate}) : _onGuiUpdate = onGuiUpdate;

  /// All available tools
  List<Map<String, dynamic>> get _allTools => [...gmailTools, ...windowTools];

  /// Process a natural language message with context
  Future<String> process(String userMessage, {AgentContext? context}) async {
    // Limit conversation history to last 10 exchanges to keep tokens low
    if (_conversationHistory.length > 20) {
      _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
    }

    _conversationHistory.add({
      'role': 'user',
      'content': userMessage,
    });

    // Build system prompt with context and store for recursive calls
    final contextStr = context?.toPromptString() ?? 'No context available.';
    _currentSystemPrompt = kSystemPrompt.replaceAll('{context}', contextStr);

    try {
      final response = await _client.createMessage(
        system: _currentSystemPrompt,
        messages: _conversationHistory,
        tools: _allTools,
      );

      return await _handleResponse(response);
    } catch (e) {
      debugPrint('Agent error: $e');
      return 'Sorry, I encountered an error. Please try again.';
    }
  }

  /// Handle Claude's response, executing tools if needed
  Future<String> _handleResponse(Map<String, dynamic> response) async {
    final content = response['content'] as List<dynamic>;
    final assistantContent = <Map<String, dynamic>>[];
    var finalText = '';

    for (final block in content) {
      final blockMap = block as Map<String, dynamic>;
      final type = blockMap['type'] as String;

      if (type == 'text') {
        finalText += blockMap['text'] as String;
        assistantContent.add(blockMap);
      } else if (type == 'tool_use') {
        assistantContent.add(blockMap);

        final toolName = blockMap['name'] as String;
        final toolInput = blockMap['input'] as Map<String, dynamic>;
        final toolId = blockMap['id'] as String;

        debugPrint('[Executing tool: $toolName]');

        // Execute the tool
        final result = await _executeTool(toolName, toolInput);

        // Add assistant's response with tool use to history
        _conversationHistory.add({
          'role': 'assistant',
          'content': assistantContent,
        });

        // Add tool result
        _conversationHistory.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': toolId,
              'content': result,
            }
          ],
        });

        // Get Claude's final response after tool execution
        final followUp = await _client.createMessage(
          system: _currentSystemPrompt,
          messages: _conversationHistory,
          tools: _allTools,
        );

        // Recursively handle (in case of multiple tool calls)
        return _handleResponse(followUp);
      }
    }

    // No tool calls - just text response
    if (assistantContent.isNotEmpty) {
      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantContent,
      });
    }

    return finalText;
  }

  /// Route tool execution to the appropriate handler
  Future<String> _executeTool(String toolName, Map<String, dynamic> input) async {
    if (windowToolNames.contains(toolName)) {
      return _windowExecutor.execute(toolName, input);
    }
    return _executeGmailTool(toolName, input);
  }

  /// Execute Gmail tools
  Future<String> _executeGmailTool(String toolName, Map<String, dynamic> input) async {
    switch (toolName) {
      case 'check_inbox':
        return _checkInbox();
      case 'list_emails':
        return _listEmails(input);
      case 'list_unread_emails':
        return _listUnreadEmails(input);
      case 'read_email':
        return _readEmail(input);
      case 'search_emails':
        return _searchEmails(input);
      case 'send_email':
        return _sendEmail(input);
      case 'reply_to_email':
        return _replyToEmail(input);
      case 'delete_email':
        return _deleteEmail(input);
      case 'archive_email':
        return _archiveEmail(input);
      case 'mark_as_read':
        return _markAsRead(input);
      case 'apply_label':
        return _applyLabel(input);
      case 'remove_label':
        return _removeLabel(input);
      case 'list_labels':
        return _listLabels();
      case 'add_contact':
        return _addContact(input);
      case 'remove_contact':
        return _removeContact(input);
      case 'list_contacts':
        return _listContacts();
      case 'find_contact':
        return _findContact(input);
      case 'add_sender_to_contacts':
        return _addSenderToContacts(input);
      default:
        return 'Unknown tool: $toolName';
    }
  }

  // Gmail tool implementations

  Future<String> _checkInbox() async {
    final count = await _gmail.getUnreadCount();
    if (count == 0) {
      return 'Your inbox is empty. No unread messages.';
    } else if (count == 1) {
      return 'You have 1 unread message.';
    }
    return 'You have $count unread messages.';
  }

  Future<String> _listEmails(Map<String, dynamic> input) async {
    final folder = input['folder'] as String? ?? 'inbox';
    final maxResults = input['max_results'] as int? ?? 10;
    final unreadOnly = input['unread_only'] as bool? ?? false;

    // Build query
    final folderQueries = {
      'inbox': 'in:inbox',
      'sent': 'in:sent',
      'starred': 'is:starred',
      'drafts': 'in:drafts',
      'spam': 'in:spam',
      'trash': 'in:trash',
      'all': '',
    };

    var query = folderQueries[folder.toLowerCase()] ?? 'label:$folder';
    if (unreadOnly) {
      query = '$query is:unread'.trim();
    }

    _currentEmails = await _gmail.listEmails(query: query, maxResults: maxResults);

    if (_currentEmails.isEmpty) {
      return 'No emails found in $folder.';
    }

    // Notify GUI
    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    _onGuiUpdate?.call('setStatus', 'Showing ${_currentEmails.length} emails from $folder');

    return 'Here are ${_currentEmails.length} emails from $folder.';
  }

  Future<String> _listUnreadEmails(Map<String, dynamic> input) async {
    final maxResults = input['max_results'] as int? ?? 10;
    _currentEmails = await _gmail.getUnreadEmails(maxResults: maxResults);

    if (_currentEmails.isEmpty) {
      return 'No unread emails.';
    }

    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    _onGuiUpdate?.call('setStatus', 'Showing ${_currentEmails.length} unread emails');

    return "You have ${_currentEmails.length} unread emails. They're on your screen.";
  }

  Future<String> _readEmail(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number. Please choose between 1 and ${_currentEmails.length}.';
    }

    final email = _currentEmails[idx];
    final fullEmail = await _gmail.getEmail(email.id, includeBody: true);
    if (fullEmail == null) {
      return 'Could not retrieve email.';
    }

    await _gmail.markAsRead(email.id);

    // Update current emails with full content
    _currentEmails[idx] = fullEmail;

    // Notify GUI
    _onGuiUpdate?.call('showEmail', {'email': fullEmail, 'number': emailNumber});

    final senderName = _extractSenderName(fullEmail.sender);
    _onGuiUpdate?.call('setStatus', 'Email from $senderName');

    return "Here's the email from $senderName.";
  }

  Future<String> _searchEmails(Map<String, dynamic> input) async {
    final query = input['query'] as String;
    final maxResults = input['max_results'] as int? ?? 10;

    _currentEmails = await _gmail.searchEmails(query, maxResults: maxResults);

    if (_currentEmails.isEmpty) {
      return "No emails found matching '$query'.";
    }

    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    _onGuiUpdate?.call('setStatus', 'Search: $query');

    return "Found ${_currentEmails.length} emails. They're on your screen.";
  }

  Future<String> _sendEmail(Map<String, dynamic> input) async {
    final to = input['to'] as String;
    final subject = input['subject'] as String;
    final body = input['body'] as String;

    // Resolve contact name to email
    final resolvedEmail = await _addressBook.resolveEmail(to);
    if (resolvedEmail == null) {
      return "Could not find contact '$to'. Please add them to your addressbook first or use their email address.";
    }

    final success = await _gmail.sendEmail(
      to: resolvedEmail,
      subject: subject,
      body: body,
    );

    if (success) {
      if (resolvedEmail != to) {
        return 'Email sent successfully to $to ($resolvedEmail).';
      }
      return 'Email sent successfully to $to.';
    }
    return 'Failed to send email.';
  }

  Future<String> _replyToEmail(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;
    final body = input['body'] as String;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.replyToEmail(email, body);

    if (success) {
      final senderName = _extractSenderName(email.sender);
      return 'Reply sent to $senderName.';
    }
    return 'Failed to send reply.';
  }

  Future<String> _deleteEmail(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.deleteEmail(email.id);

    if (success) {
      _currentEmails.removeAt(idx);
      _onGuiUpdate?.call('updateEmailList', _currentEmails);
      return 'Email moved to trash.';
    }
    return 'Failed to delete email.';
  }

  Future<String> _archiveEmail(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.archiveEmail(email.id);

    if (success) {
      _currentEmails.removeAt(idx);
      _onGuiUpdate?.call('updateEmailList', _currentEmails);
      return 'Email archived.';
    }
    return 'Failed to archive email.';
  }

  Future<String> _markAsRead(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.markAsRead(email.id);

    if (success) {
      return 'Email marked as read.';
    }
    return 'Failed to mark as read.';
  }

  Future<String> _applyLabel(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;
    final label = input['label'] as String;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.applyLabel(email.id, label);

    if (success) {
      return "Label '$label' applied to email $emailNumber.";
    }
    return "Failed to apply label '$label'.";
  }

  Future<String> _removeLabel(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;
    final label = input['label'] as String;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number.';
    }

    final email = _currentEmails[idx];
    final success = await _gmail.removeLabel(email.id, label);

    if (success) {
      return "Label '$label' removed from email $emailNumber.";
    }
    return "Failed to remove label '$label'.";
  }

  Future<String> _listLabels() async {
    final labels = await _gmail.listLabels();
    if (labels.isEmpty) {
      return 'No labels found.';
    }

    // Filter out category labels
    final userLabels = labels.where((l) => !l.id.startsWith('CATEGORY_')).toList();

    final buffer = StringBuffer('Your labels:\n');
    for (final label in userLabels..sort((a, b) => a.name.compareTo(b.name))) {
      buffer.writeln('  - ${label.name}');
    }
    return buffer.toString();
  }

  Future<String> _addContact(Map<String, dynamic> input) async {
    final name = input['name'] as String;
    final email = input['email'] as String;

    final contact = await _addressBook.add(name, email);
    return 'Added ${contact.name} (${contact.email}) to your addressbook.';
  }

  Future<String> _removeContact(Map<String, dynamic> input) async {
    final name = input['name'] as String;

    final success = await _addressBook.remove(name);
    if (success) {
      return 'Removed $name from your addressbook.';
    }
    return "Contact '$name' not found in addressbook.";
  }

  Future<String> _listContacts() async {
    final contacts = await _addressBook.listAll();
    if (contacts.isEmpty) {
      return 'Your addressbook is empty.';
    }

    // Show contacts in GUI
    _onGuiUpdate?.call('showContacts', contacts);
    _onGuiUpdate?.call('setStatus', 'Showing ${contacts.length} contacts');

    return 'Showing ${contacts.length} contacts.';
  }

  Future<String> _findContact(Map<String, dynamic> input) async {
    final name = input['name'] as String;

    final contact = await _addressBook.get(name);
    if (contact != null) {
      return '${contact.name}: ${contact.email}';
    }

    final matches = await _addressBook.search(name);
    if (matches.isNotEmpty) {
      final buffer = StringBuffer('Found ${matches.length} matching contacts:\n');
      for (final c in matches) {
        buffer.writeln('  ${c.name}: ${c.email}');
      }
      return buffer.toString();
    }

    return "No contact found matching '$name'.";
  }

  Future<String> _addSenderToContacts(Map<String, dynamic> input) async {
    final emailNumber = input['email_number'] as int;
    final nickname = input['nickname'] as String?;

    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    final idx = emailNumber - 1;
    if (idx < 0 || idx >= _currentEmails.length) {
      return 'Invalid email number. Please choose between 1 and ${_currentEmails.length}.';
    }

    final email = _currentEmails[idx];
    final sender = email.sender;

    // Extract email address and name from sender string like "John Doe <john@example.com>"
    String senderEmail;
    String senderName;

    if (sender.contains('<') && sender.contains('>')) {
      final emailMatch = RegExp(r'<([^>]+)>').firstMatch(sender);
      senderEmail = emailMatch?.group(1) ?? sender;
      senderName = sender.split('<')[0].trim().replaceAll('"', '');
    } else {
      senderEmail = sender;
      senderName = sender.split('@')[0];
    }

    // Use nickname if provided, otherwise use extracted name
    final contactName = nickname ?? senderName;

    // Check if already exists
    final existing = await _addressBook.get(contactName);
    if (existing != null) {
      return '${existing.name} is already in your contacts (${existing.email}).';
    }

    final contact = await _addressBook.add(contactName, senderEmail);
    return 'Added ${contact.name} (${contact.email}) to your contacts.';
  }

  String _extractSenderName(String sender) {
    if (sender.contains('<')) {
      return sender.split('<')[0].trim().replaceAll('"', '');
    }
    return sender;
  }

  /// Reset conversation history
  void resetConversation() {
    _conversationHistory.clear();
  }

  /// Get current emails
  List<Email> get currentEmails => _currentEmails;
}
