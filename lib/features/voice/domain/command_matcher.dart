import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Result of matching a voice command
class CommandMatch {
  final String command;      // e.g., "delete_email"
  final Map<String, dynamic> args;  // e.g., {number: 3}
  final int confidence;      // 0-100
  final String? original;    // Original transcription

  CommandMatch({
    required this.command,
    this.args = const {},
    required this.confidence,
    this.original,
  });

  bool get isConfident => confidence >= 70;

  @override
  String toString() => 'CommandMatch($command, $args, confidence: $confidence)';
}

/// Matches voice transcriptions to known commands using fuzzy matching
class CommandMatcher {
  // Minimum confidence to consider a match
  static const int _minConfidence = 60;

  /// Command patterns with their variations
  /// Each entry: canonical command -> list of phrase variations
  static const Map<String, List<String>> _commands = {
    // Inbox Navigation
    'show_inbox': ['show inbox', 'show my inbox', 'open inbox', 'go to inbox', 'inbox'],
    'show_unread': ['show unread', 'unread emails', 'new emails', 'unread', 'show unread emails'],
    'show_sent': ['show sent', 'sent mail', 'sent emails', 'sent folder'],
    'show_drafts': ['show drafts', 'my drafts', 'drafts'],
    'show_starred': ['show starred', 'starred emails', 'starred'],
    'show_spam': ['show spam', 'spam folder', 'spam'],
    'show_trash': ['show trash', 'trash', 'deleted emails', 'trash folder'],
    'check_inbox': ['check inbox', 'how many emails', 'email count', 'check email'],
    'refresh': ['refresh', 'refresh inbox', 'check for new', 'reload'],

    // Email Reading (without number - uses "current" or "this")
    'next_email': ['next', 'next email', 'next one', 'show next'],
    'previous_email': ['previous', 'previous email', 'go back', 'last one', 'back'],
    'first_email': ['first email', 'go to first', 'first'],
    'last_email': ['last email', 'go to last', 'last'],

    // Email Actions (on current email)
    'delete': ['delete', 'delete this', 'delete email', 'trash this', 'trash it', 'delete it'],
    'archive': ['archive', 'archive this', 'archive email', 'done with this', 'archive it'],
    'mark_read': ['mark read', 'mark as read'],
    'mark_unread': ['mark unread', 'mark as unread'],
    'star': ['star', 'star this', 'star email', 'star it'],
    'unstar': ['unstar', 'unstar this', 'remove star'],

    // Labels
    'show_labels': ['show labels', 'list labels', 'my labels'],

    // Composing
    'compose': ['compose', 'new email', 'write email', 'compose email'],
    'reply': ['reply', 'reply to this', 'respond'],
    'reply_all': ['reply all', 'reply to all'],
    'forward': ['forward', 'forward this', 'forward email'],

    // Draft actions
    'send': ['send', 'send it', 'send email', 'send draft'],
    'cancel_draft': ['cancel', 'cancel email', 'discard', 'nevermind', 'cancel draft'],
    'show_draft': ['show draft', 'read draft', 'what did i write'],

    // Attachments
    'open_attachment': ['open attachment', 'show attachment', 'view attachment', 'open the attachment'],
    'open_pdf': ['open pdf', 'show pdf', 'view pdf', 'open the pdf'],

    // PDF Viewer
    'scroll_down': ['scroll down', 'down', 'go down'],
    'scroll_up': ['scroll up', 'up', 'go up'],
    'next_page': ['next page', 'page down'],
    'previous_page': ['previous page', 'page up'],
    'first_page': ['first page', 'go to start', 'beginning'],
    'last_page': ['last page', 'go to end', 'end'],
    'zoom_in': ['zoom in', 'bigger'],
    'zoom_out': ['zoom out', 'smaller'],
    'close': ['close', 'close pdf', 'back', 'exit'],

    // Contacts
    'show_contacts': ['show contacts', 'list contacts', 'my contacts'],
    'save_sender': ['save sender', 'add sender to contacts', 'save this sender'],

    // Pagination
    'more': ['more', 'show more', 'more emails', 'load more'],

    // System
    'stop': ['stop', 'stop listening'],
    'help': ['help', 'what can i say', 'commands'],
    'repeat': ['repeat', 'say again', 'what'],
  };

  /// Commands that take a number argument
  static const List<String> _numberCommands = [
    'open_email',
    'delete_email',
    'archive_email',
    'open_attachment_n',
    'page',
  ];

  /// Patterns for number commands
  static const Map<String, List<String>> _numberPatterns = {
    'open_email': ['open email', 'read email', 'show email', 'email'],
    'delete_email': ['delete email', 'trash email', 'delete'],
    'archive_email': ['archive email', 'archive'],
    'open_attachment_n': ['open attachment', 'attachment'],
    'page': ['page', 'go to page', 'page number'],
  };

  /// Commands that take a name/text argument
  static const Map<String, List<String>> _textPatterns = {
    'label': ['label', 'label this', 'add label'],
    'remove_label': ['remove label', 'unlabel'],
    'show_label': ['show label', 'open label'],
    'search': ['search', 'find', 'search for'],
    'from': ['from', 'emails from', 'show from'],
    'email_to': ['email', 'send email to', 'write to'],
    'find_contact': ['find contact', 'search contact'],
    'message': ['message', 'body', 'say'],
    'continue_message': ['continue', 'add', 'also say'],
    'subject': ['subject', 'subject is'],
  };

  /// Number word mappings
  static const Map<String, int> _numberWords = {
    'one': 1, 'won': 1, 'want': 1,
    'two': 2, 'to': 2, 'too': 2,
    'three': 3, 'tree': 3,
    'four': 4, 'for': 4, 'fore': 4,
    'five': 5,
    'six': 6, 'sicks': 6,
    'seven': 7,
    'eight': 8, 'ate': 8,
    'nine': 9,
    'ten': 10,
  };

  /// Match a transcription to a command
  CommandMatch? match(String transcription) {
    final normalized = _normalize(transcription);

    // Try exact/fuzzy match against simple commands first
    final simpleMatch = _matchSimpleCommand(normalized);
    if (simpleMatch != null && simpleMatch.isConfident) {
      return simpleMatch;
    }

    // Try to match number commands (e.g., "open email 3")
    final numberMatch = _matchNumberCommand(normalized);
    if (numberMatch != null && numberMatch.isConfident) {
      return numberMatch;
    }

    // Try to match text commands (e.g., "label important")
    final textMatch = _matchTextCommand(normalized);
    if (textMatch != null && textMatch.isConfident) {
      return textMatch;
    }

    // Return best match even if not confident (caller can decide)
    return simpleMatch ?? numberMatch ?? textMatch;
  }

  /// Match against simple commands (no arguments)
  CommandMatch? _matchSimpleCommand(String text) {
    CommandMatch? bestMatch;
    int bestScore = 0;

    for (final entry in _commands.entries) {
      for (final variation in entry.value) {
        final score = ratio(text, variation);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = CommandMatch(
            command: entry.key,
            confidence: score,
            original: text,
          );
        }
      }
    }

    return bestMatch;
  }

  /// Match commands with number arguments
  CommandMatch? _matchNumberCommand(String text) {
    // Extract number from text
    final number = _extractNumber(text);
    if (number == null) return null;

    // Remove the number from text for matching
    final textWithoutNumber = _removeNumber(text);

    CommandMatch? bestMatch;
    int bestScore = 0;

    for (final entry in _numberPatterns.entries) {
      for (final pattern in entry.value) {
        final score = ratio(textWithoutNumber, pattern);
        if (score > bestScore && score >= _minConfidence) {
          bestScore = score;
          bestMatch = CommandMatch(
            command: entry.key,
            args: {'number': number},
            confidence: score,
            original: text,
          );
        }
      }
    }

    return bestMatch;
  }

  /// Match commands with text arguments
  CommandMatch? _matchTextCommand(String text) {
    CommandMatch? bestMatch;
    int bestScore = 0;

    for (final entry in _textPatterns.entries) {
      for (final pattern in entry.value) {
        // Check if text starts with pattern
        if (text.startsWith(pattern) ||
            ratio(text.substring(0, text.length.clamp(0, pattern.length + 5)), pattern) >= 70) {

          // Extract the argument (everything after the pattern)
          String arg = '';
          if (text.length > pattern.length) {
            arg = text.substring(pattern.length).trim();
          }

          final score = ratio(text.substring(0, pattern.length.clamp(0, text.length)), pattern);
          if (score > bestScore && arg.isNotEmpty) {
            bestScore = score;
            bestMatch = CommandMatch(
              command: entry.key,
              args: {'text': arg},
              confidence: score,
              original: text,
            );
          }
        }
      }
    }

    return bestMatch;
  }

  /// Extract number from text
  int? _extractNumber(String text) {
    // Try to find a digit
    final digitMatch = RegExp(r'\d+').firstMatch(text);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(0)!);
    }

    // Try to find a number word
    final words = text.split(RegExp(r'\s+'));
    for (final word in words) {
      if (_numberWords.containsKey(word)) {
        return _numberWords[word];
      }
    }

    return null;
  }

  /// Remove number (digit or word) from text
  String _removeNumber(String text) {
    // Remove digits
    var result = text.replaceAll(RegExp(r'\d+'), '');

    // Remove number words
    for (final word in _numberWords.keys) {
      result = result.replaceAll(RegExp('\\b$word\\b'), '');
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalize text for matching
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')    // Normalize whitespace
        .trim();
  }

  /// Get all available commands (for help display)
  List<String> getAllCommands() {
    final commands = <String>[];
    commands.addAll(_commands.keys);
    commands.addAll(_numberPatterns.keys);
    commands.addAll(_textPatterns.keys);
    return commands;
  }
}
