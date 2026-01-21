import 'package:flutter/foundation.dart';

import '../../addressbook/data/addressbook.dart';
import '../../gmail/data/email_model.dart';
import '../../gmail/data/gmail_repository.dart';
import '../../gmail/tools/gmail_tools.dart';
import '../data/anthropic_client.dart';

/// System prompt for the voice agent
const String kSystemPrompt = '''You are a voice-controlled email assistant for a user who cannot use their hands. They rely entirely on voice to manage their email.

## TYPICAL USER WORKFLOW

The user's main workflow is:
1. **Inbox triage** - Open inbox, go through emails one by one, deciding to DELETE, LABEL, or ARCHIVE each
2. **PDF review** - Find emails with PDF attachments, open them, view the PDF, scroll or jump to pages
3. **Quick responses** - Occasionally reply to emails

When triaging, they'll say things like:
- "delete this" / "trash it" / "get rid of it"
- "archive" / "done with this"
- "label this important" / "mark as work"
- "next" / "next email" / "show me the next one"

When viewing PDFs:
- "open the attachment" / "show me the PDF"
- "scroll down" / "scroll up" / "go to page 5" / "next page"

## STOP AND THINK

Before choosing a tool, pause and reason through:

1. **WHAT did they likely say?** Speech-to-text is unreliable. The transcription you receive is often wrong.
   - The input may include `[ALT: ...]` with alternative interpretations - USE THESE!
   - Example: "delayed amen [ALT: delete email | the late amen]" → they said "delete email"
   - Numbers become homophones: "to/too/two"→2, "for/four"→4, "won/one"→1, "ate/eight"→8
   - Names get mangled: "John"→"Jon"/"Juan", "Sarah"→"Sara"/"Sera"
   - Commands get garbled: "delete"→"delayed"/"the lead", "inbox"→"in box"/"inebo", "email"→"amen"/"a male"
   - PDF commands: "scroll"→"scrawl"/"scrol", "page"→"paid"/"paged", "attachment"→"attach mint"

2. **WHY are they asking this?** Consider their workflow:
   - Did they just list emails? → They probably want to read one
   - Are they viewing an email? → "this/it/that" refers to THAT email
   - Did they just read an email? → They want to DELETE, ARCHIVE, LABEL, or move to NEXT
   - Are they viewing a PDF? → They want to SCROLL or go to a PAGE
   - Are they composing? → "send/done/finished" means send the draft

3. **WHAT do they want to accomplish?** Think about the end goal:
   - "delayed amen" → probably "delete email" (they want to remove something)
   - "show me John's stuff" → search for emails from John
   - "get rid of this" → delete or archive the current email
   - "open the file" / "show attachment" → open_attachment
   - "scrawl down" / "go down" → scroll the PDF down
   - "paid five" / "page 5" → go to page 5 in PDF

## USE THE CONTEXT

Look at the current state below. It tells you:
- What folder they're viewing
- Which email is selected (if any)
- The email list with senders and subjects

When they say "this", "it", "that one", "the email" → use the SELECTED email from context.
When they say a number → it's the position in the email list (1 = first, 2 = second).
When they mention a name → check if it matches a sender in the list OR a contact.

## RESPONSE STYLE

Keep responses BRIEF - they hear this via text-to-speech:
- Good: "Deleted." / "3 unread." / "Showing inbox."
- Bad: "I have successfully deleted the email for you."

## EMAIL COMPOSITION

NEVER send emails directly. Always draft first:
1. `draft_email` or `draft_reply` → start composing
2. `continue_draft` → user adds more content
3. `send_draft` → user confirms sending
4. `cancel_draft` → user abandons

## CURRENT STATE

{context}

{action_history}

{draft_status}''';

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

/// Email draft being composed
class EmailDraft {
  String? to;
  String? subject;
  String body;
  bool isReply;
  Email? replyTo;

  EmailDraft({
    this.to,
    this.subject,
    this.body = '',
    this.isReply = false,
    this.replyTo,
  });

  String get statusDescription {
    if (to == null && subject == null && body.isEmpty) {
      return 'No draft in progress.';
    }
    final recipient = to ?? (replyTo != null ? 'reply to ${replyTo!.sender}' : 'unknown');
    final subj = subject ?? (replyTo != null ? 'Re: ${replyTo!.subject}' : 'no subject');
    final bodyPreview = body.length > 50 ? '${body.substring(0, 50)}...' : body;
    return 'DRAFT IN PROGRESS:\n  To: $recipient\n  Subject: $subj\n  Body so far: "$bodyPreview"\n  Say "continue" to add more, "send" to send, or "cancel" to discard.';
  }

  bool get isEmpty => to == null && subject == null && body.isEmpty && replyTo == null;
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

  // Draft email state
  EmailDraft? _currentDraft;

  // Action history since current email was selected (for context)
  List<String> _actionHistory = [];
  int? _currentEmailIndex; // Track which email is selected

  EmailAgent(this._gmail, {GuiCallback? onGuiUpdate}) : _onGuiUpdate = onGuiUpdate;

  /// Record an action for context history
  void _recordAction(String action) {
    _actionHistory.add(action);
    // Keep last 10 actions max
    if (_actionHistory.length > 10) {
      _actionHistory.removeAt(0);
    }
  }

  /// Clear action history (when selecting a new email or changing context)
  void _clearHistory() {
    _actionHistory.clear();
  }

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

    // Build system prompt with context, action history, and draft status
    final contextStr = context?.toPromptString() ?? 'No context available.';
    final draftStatus = _currentDraft?.isEmpty ?? true
        ? 'No draft in progress.'
        : _currentDraft!.statusDescription;
    final actionHistoryStr = _actionHistory.isEmpty
        ? 'No recent actions.'
        : 'Recent actions:\n${_actionHistory.map((a) => '  - $a').join('\n')}';
    _currentSystemPrompt = kSystemPrompt
        .replaceAll('{context}', contextStr)
        .replaceAll('{action_history}', actionHistoryStr)
        .replaceAll('{draft_status}', draftStatus);

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
      case 'next_email':
        return _nextEmail(input);
      case 'previous_email':
        return _previousEmail(input);
      // Draft email tools
      case 'draft_email':
        return _draftEmail(input);
      case 'draft_reply':
        return _draftReply(input);
      case 'continue_draft':
        return _continueDraft(input);
      case 'send_draft':
        return _sendDraft(input);
      case 'cancel_draft':
        return _cancelDraft(input);
      case 'show_draft':
        return _showDraft(input);
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

    // New folder view - clear history
    _clearHistory();
    _currentEmailIndex = null;

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

    _recordAction('Listed $folder (${_currentEmails.length} emails)');
    return 'Showing ${_currentEmails.length} emails.$hasMore';
  }

  Future<String> _openAttachment(Map<String, dynamic> input) async {
    final attachmentIndex = (input['attachment_index'] as int?) ?? 1;

    if (_currentEmails.isEmpty) {
      return 'No email selected.';
    }

    // Signal GUI to open attachment
    _onGuiUpdate?.call('openAttachment', {'index': attachmentIndex});
    _recordAction('Opened attachment $attachmentIndex');
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

    // If opening a different email, clear action history
    if (_currentEmailIndex != idx) {
      _clearHistory();
      _currentEmailIndex = idx;
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

    _recordAction('Opened email $emailNumber from $senderName: "${fullEmail.subject}"');
    return "Here's the email from $senderName.";
  }

  Future<String> _nextEmail(Map<String, dynamic> input) async {
    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    // If no email selected, start at first
    final currentIdx = _currentEmailIndex ?? -1;
    final nextIdx = currentIdx + 1;

    if (nextIdx >= _currentEmails.length) {
      return 'No more emails. This is the last one.';
    }

    // Use _readEmail to do the actual work
    return _readEmail({'email_number': nextIdx + 1});
  }

  Future<String> _previousEmail(Map<String, dynamic> input) async {
    if (_currentEmails.isEmpty) {
      return 'No emails loaded. Please list emails first.';
    }

    // If no email selected, can't go back
    final currentIdx = _currentEmailIndex ?? 0;

    if (currentIdx <= 0) {
      return 'Already at the first email.';
    }

    // Use _readEmail to do the actual work
    return _readEmail({'email_number': currentIdx}); // currentIdx is already 0-based, +1 would be current, so just use currentIdx for previous
  }

  Future<String> _searchEmails(Map<String, dynamic> input) async {
    final query = input['query'] as String;
    final maxResults = input['max_results'] as int? ?? 10;

    // New search - clear history
    _clearHistory();
    _currentEmailIndex = null;

    _currentEmails = await _gmail.searchEmails(query, maxResults: maxResults);

    if (_currentEmails.isEmpty) {
      return "No emails found matching '$query'.";
    }

    _onGuiUpdate?.call('updateEmailList', _currentEmails);
    _onGuiUpdate?.call('setStatus', 'Search: $query');

    _recordAction('Searched for "$query" (${_currentEmails.length} results)');
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
      _recordAction('Deleted email $emailNumber');
      _currentEmailIndex = null; // No email selected after delete
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
      _recordAction('Archived email $emailNumber');
      _currentEmailIndex = null; // No email selected after archive
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

  // Draft email tool implementations

  Future<String> _draftEmail(Map<String, dynamic> input) async {
    final to = input['to'] as String;
    final subject = input['subject'] as String;
    final body = input['body'] as String? ?? '';

    _currentDraft = EmailDraft(
      to: to,
      subject: subject,
      body: body,
    );

    // Notify GUI to show draft
    _onGuiUpdate?.call('showDraft', {
      'to': to,
      'subject': subject,
      'body': body,
    });

    _recordAction('Started draft to $to: "$subject"');
    if (body.isEmpty) {
      return 'Draft started to $to about "$subject". Dictate your message, say "pause" to stop, or "send" when ready.';
    }
    return 'Draft to $to: "$subject". Say "continue" to add more, "send" to send, or "cancel" to discard.';
  }

  Future<String> _draftReply(Map<String, dynamic> input) async {
    final body = input['body'] as String? ?? '';

    // Need a selected email to reply to
    if (_currentEmails.isEmpty) {
      return 'No email selected to reply to.';
    }

    // Find selected email from GUI context (assume first if none selected)
    // In practice, the context will tell us which email is selected
    final selectedEmail = _currentEmails.first;

    _currentDraft = EmailDraft(
      body: body,
      isReply: true,
      replyTo: selectedEmail,
    );

    // Notify GUI
    _onGuiUpdate?.call('showDraft', {
      'to': selectedEmail.sender,
      'subject': 'Re: ${selectedEmail.subject}',
      'body': body,
      'isReply': true,
    });

    final senderName = _extractSenderName(selectedEmail.sender);
    _recordAction('Started reply to $senderName');
    if (body.isEmpty) {
      return 'Reply to $senderName started. Dictate your message, say "pause" to stop, or "send" when ready.';
    }
    return 'Reply to $senderName drafted. Say "continue" to add more, "send" to send, or "cancel" to discard.';
  }

  Future<String> _continueDraft(Map<String, dynamic> input) async {
    if (_currentDraft == null || _currentDraft!.isEmpty) {
      return 'No draft in progress. Start with "send email to..." or "reply to this".';
    }

    final additionalText = input['additional_text'] as String;

    // Append to body with space/newline
    if (_currentDraft!.body.isEmpty) {
      _currentDraft!.body = additionalText;
    } else {
      _currentDraft!.body = '${_currentDraft!.body} $additionalText';
    }

    // Notify GUI
    _onGuiUpdate?.call('updateDraft', {
      'body': _currentDraft!.body,
    });

    _recordAction('Added to draft: "$additionalText"');
    return 'Added to draft. Say "continue" to add more, "send" to send, or "cancel" to discard.';
  }

  Future<String> _sendDraft(Map<String, dynamic> input) async {
    if (_currentDraft == null || _currentDraft!.isEmpty) {
      return 'No draft to send.';
    }

    final draft = _currentDraft!;
    bool success;

    if (draft.isReply && draft.replyTo != null) {
      // Send as reply
      success = await _gmail.replyToEmail(draft.replyTo!, draft.body);
      if (success) {
        final senderName = _extractSenderName(draft.replyTo!.sender);
        _currentDraft = null;
        _onGuiUpdate?.call('clearDraft', null);
        _recordAction('Sent reply to $senderName');
        return 'Reply sent to $senderName.';
      }
    } else {
      // Send as new email
      final resolvedEmail = await _addressBook.resolveEmail(draft.to!);
      if (resolvedEmail == null) {
        return "Could not find contact '${draft.to}'. Add them to contacts or use their email address.";
      }

      success = await _gmail.sendEmail(
        to: resolvedEmail,
        subject: draft.subject!,
        body: draft.body,
      );

      if (success) {
        _currentDraft = null;
        _onGuiUpdate?.call('clearDraft', null);
        _recordAction('Sent email to ${draft.to}');
        if (resolvedEmail != draft.to) {
          return 'Sent to ${draft.to} ($resolvedEmail).';
        }
        return 'Sent to ${draft.to}.';
      }
    }

    return 'Failed to send. Try again or say "cancel" to discard.';
  }

  Future<String> _cancelDraft(Map<String, dynamic> input) async {
    if (_currentDraft == null || _currentDraft!.isEmpty) {
      return 'No draft to cancel.';
    }

    _currentDraft = null;
    _onGuiUpdate?.call('clearDraft', null);
    _recordAction('Cancelled draft');
    return 'Draft discarded.';
  }

  Future<String> _showDraft(Map<String, dynamic> input) async {
    if (_currentDraft == null || _currentDraft!.isEmpty) {
      return 'No draft in progress.';
    }

    final draft = _currentDraft!;
    if (draft.isReply && draft.replyTo != null) {
      return 'Reply to ${_extractSenderName(draft.replyTo!.sender)}: "${draft.body}". Say "continue" to add more, "send" to send, or "cancel".';
    }
    return 'Email to ${draft.to}, subject "${draft.subject}": "${draft.body}". Say "continue" to add more, "send" to send, or "cancel".';
  }
}
