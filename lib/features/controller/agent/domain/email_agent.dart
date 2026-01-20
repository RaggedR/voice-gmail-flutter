import 'package:flutter/foundation.dart';

import '../../addressbook/data/addressbook.dart';
import '../../gmail/data/email_model.dart';
import '../../gmail/data/gmail_repository.dart';
import '../../gmail/tools/gmail_tools.dart';
import '../data/anthropic_client.dart';

/// System prompt for the voice agent
const String kSystemPrompt = '''Voice email assistant.

INPUT: Speech-to-text with errors. Numbers often transcribed as homophones: "to/too"=2, "for"=4, "won"=1, "ate"=8, etc.

OUTPUT: Silent. Just use tools. Never explain.

{context}''';

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
  final GuiCallback? _onGuiUpdate;

  List<Email> _currentEmails = [];
  List<Map<String, dynamic>> _conversationHistory = [];
  String _currentSystemPrompt = kSystemPrompt;

  // Pagination state
  String? _currentQuery;
  int _currentPage = 1;
  List<String?> _pageTokens = [null]; // Index 0 = page 1 (no token needed)
  String? _nextPageToken;

  EmailAgent(this._gmail, {GuiCallback? onGuiUpdate}) : _onGuiUpdate = onGuiUpdate;

  /// All available tools
  List<Map<String, dynamic>> get _allTools => gmailTools;

  /// Process a natural language message with context
  Future<String> process(String userMessage, {AgentContext? context}) async {
    print('[Agent] Input: "$userMessage"');

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

      print('[Agent] Response: ${response['content']}');
      return await _handleResponse(response);
    } catch (e) {
      print('[Agent] Error: $e');
      return 'Error.';
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

        // Add tool result to history (for context in future calls)
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

        // Tool executed - no speech needed, user sees the result
        return '';
      }
    }

    // No tool calls - Claude didn't understand or couldn't help
    if (assistantContent.isNotEmpty) {
      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantContent,
      });
    }

    // Don't return Claude's verbose text - just say Error
    return 'Error.';
  }

  /// Execute a tool and return the result
  Future<String> _executeTool(String toolName, Map<String, dynamic> input) async {
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
      case 'open_attachment':
        return _openAttachment(input);
      case 'next_page':
        return _nextPage(input);
      case 'previous_page':
        return _previousPage(input);
      default:
        return 'Unknown tool: $toolName';
    }
  }

  // Gmail tool implementations

  Future<String> _checkInbox() async {
    final unreadCount = await _gmail.getUnreadCount();
    final totalCount = await _gmail.getInboxCount();

    if (unreadCount == 0) {
      return 'You have $totalCount emails in your inbox. No unread.';
    } else if (unreadCount == 1) {
      return 'You have $totalCount emails in your inbox, 1 unread.';
    }
    return 'You have $totalCount emails in your inbox, $unreadCount unread.';
  }

  Future<String> _listEmails(Map<String, dynamic> input) async {
    final folder = input['folder'] as String? ?? 'inbox';
    final maxResults = input['max_results'] as int? ?? 10;
    final unreadOnly = input['unread_only'] as bool? ?? false;

    // Build query - inbox uses category:primary to exclude promotions/social/updates
    final folderQueries = {
      'inbox': 'in:inbox category:primary',
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

    // Reset pagination state for new query
    _currentQuery = query;
    _currentPage = 1;
    _pageTokens = [null];
    _nextPageToken = null;

    // Fetch more emails to account for thread deduplication
    final fetchCount = maxResults * 2;
    final (emails, nextToken) = await _gmail.listEmailsWithPagination(
      query: query,
      maxResults: fetchCount,
    );
    _nextPageToken = nextToken;
    print('[Pagination] Fetched ${emails.length} emails, nextToken: ${nextToken != null ? "yes" : "no"}');

    // Deduplicate by threadId (keep only the first/most recent email per thread)
    final seenThreads = <String>{};
    final deduped = <Email>[];
    for (final email in emails) {
      if (!seenThreads.contains(email.threadId)) {
        seenThreads.add(email.threadId);
        deduped.add(email);
        if (deduped.length >= maxResults) break;
      }
    }
    _currentEmails = deduped;
    print('[Pagination] After dedup: ${_currentEmails.length} emails');

    if (_currentEmails.isEmpty) {
      return 'No emails found in $folder.';
    }

    // Notify GUI
    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    final hasMore = _nextPageToken != null ? ' (more available)' : '';
    _onGuiUpdate?.call('setStatus', '${_currentEmails.length} emails$hasMore');

    return 'Showing ${_currentEmails.length} emails.$hasMore';
  }

  Future<String> _openAttachment(Map<String, dynamic> input) async {
    final attachmentIndex = (input['attachment_index'] as int?) ?? 1;

    if (_currentEmails.isEmpty) {
      return 'No email selected.';
    }

    // Signal GUI to open attachment
    _onGuiUpdate?.call('openAttachment', {'index': attachmentIndex});
    return 'Opening attachment.';
  }

  Future<String> _nextPage(Map<String, dynamic> input) async {
    print('[NextPage] Called. Token: ${_nextPageToken != null ? "yes" : "no"}, Query: $_currentQuery');
    if (_nextPageToken == null) {
      return 'No more emails.';
    }
    if (_currentQuery == null) {
      return 'Show inbox first.';
    }

    // Store current token for going back
    if (_currentPage >= _pageTokens.length) {
      _pageTokens.add(_nextPageToken);
    }

    // Fetch next page - get extra for deduplication
    final (emails, nextToken) = await _gmail.listEmailsWithPagination(
      query: _currentQuery!,
      maxResults: 20,
      pageToken: _nextPageToken,
    );

    _currentPage++;
    _nextPageToken = nextToken;
    print('[NextPage] Fetched ${emails.length} emails, nextToken: ${nextToken != null ? "yes" : "no"}');

    // Deduplicate by threadId
    final seenThreads = <String>{};
    final deduped = <Email>[];
    for (final email in emails) {
      if (!seenThreads.contains(email.threadId)) {
        seenThreads.add(email.threadId);
        deduped.add(email);
        if (deduped.length >= 10) break;
      }
    }
    _currentEmails = deduped;
    print('[NextPage] After dedup: ${_currentEmails.length} emails');

    if (_currentEmails.isEmpty) {
      return 'No more emails.';
    }

    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    final hasMore = _nextPageToken != null ? ' (more available)' : '';
    _onGuiUpdate?.call('setStatus', 'Page $_currentPage: ${_currentEmails.length} emails$hasMore');

    return 'Page $_currentPage.$hasMore';
  }

  Future<String> _previousPage(Map<String, dynamic> input) async {
    if (_currentPage <= 1) {
      return 'Already on first page.';
    }
    if (_currentQuery == null) {
      return 'Please list emails first.';
    }

    _currentPage--;

    // Get the token for the previous page (or null for page 1)
    final pageToken = _currentPage > 1 ? _pageTokens[_currentPage - 1] : null;

    // Fetch previous page
    final (emails, nextToken) = await _gmail.listEmailsWithPagination(
      query: _currentQuery!,
      maxResults: 10,
      pageToken: pageToken,
    );

    _nextPageToken = nextToken;

    // Deduplicate by threadId
    final seenThreads = <String>{};
    final deduped = <Email>[];
    for (final email in emails) {
      if (!seenThreads.contains(email.threadId)) {
        seenThreads.add(email.threadId);
        deduped.add(email);
      }
    }
    _currentEmails = deduped;

    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    _onGuiUpdate?.call('setStatus', 'Page $_currentPage: ${_currentEmails.length} emails');

    return 'Page $_currentPage: ${_currentEmails.length} emails.';
  }

  Future<String> _listUnreadEmails(Map<String, dynamic> input) async {
    final maxResults = input['max_results'] as int? ?? 20;

    // Fetch more than needed to account for thread deduplication
    final fetchCount = maxResults * 2;
    // Use primary category to exclude promotions/social/updates
    var emails = await _gmail.listEmails(
      query: 'is:unread in:inbox category:primary',
      maxResults: fetchCount,
    );

    // Deduplicate by threadId (keep only the first/most recent email per thread)
    final seenThreads = <String>{};
    final deduped = <Email>[];
    for (final email in emails) {
      if (!seenThreads.contains(email.threadId)) {
        seenThreads.add(email.threadId);
        deduped.add(email);
        if (deduped.length >= maxResults) break;
      }
    }
    _currentEmails = deduped;

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
