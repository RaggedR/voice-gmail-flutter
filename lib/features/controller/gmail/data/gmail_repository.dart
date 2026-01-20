import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'email_model.dart';
import 'gmail_auth.dart';

/// Gmail API repository for email operations
class GmailRepository {
  final GmailAuth _auth;

  static const String _baseUrl = 'https://gmail.googleapis.com/gmail/v1';
  static const String _userId = 'me';

  GmailRepository(this._auth);

  /// Get authorization headers
  Future<Map<String, String>> _headers() async {
    final token = await _auth.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get unread email count from INBOX label (accurate count)
  Future<int> getUnreadCount() async {
    try {
      // Use labels API for accurate unread count
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/labels/INBOX'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to get unread count: ${response.body}');
        return 0;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['messagesUnread'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get total email count for a query (uses estimate, may not be accurate)
  Future<int> getEmailCount(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/messages').replace(
          queryParameters: {'q': query, 'maxResults': '1'},
        ),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        return 0;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['resultSizeEstimate'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting email count: $e');
      return 0;
    }
  }

  /// Get total messages in INBOX (accurate count from labels API)
  Future<int> getInboxCount() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/labels/INBOX'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        return 0;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['messagesTotal'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting inbox count: $e');
      return 0;
    }
  }

  /// List emails matching a query with pagination support
  /// Returns a record of (emails, nextPageToken)
  Future<(List<Email>, String?)> listEmailsWithPagination({
    String query = 'in:inbox',
    int maxResults = 10,
    String? pageToken,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'maxResults': maxResults.toString(),
        if (pageToken != null) 'pageToken': pageToken,
      };

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/messages').replace(queryParameters: queryParams),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to list emails: ${response.body}');
        return (<Email>[], null);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = data['messages'] as List<dynamic>? ?? [];
      final nextPageToken = data['nextPageToken'] as String?;

      // Fetch all emails in PARALLEL for speed
      final futures = messages.map((msg) => getEmail(msg['id'] as String, includeBody: false));
      final results = await Future.wait(futures);
      return (results.whereType<Email>().toList(), nextPageToken);
    } catch (e) {
      debugPrint('Error listing emails: $e');
      return (<Email>[], null);
    }
  }

  /// List emails matching a query (simple version without pagination)
  Future<List<Email>> listEmails({
    String query = 'in:inbox',
    int maxResults = 10,
  }) async {
    final (emails, _) = await listEmailsWithPagination(
      query: query,
      maxResults: maxResults,
    );
    return emails;
  }

  /// Get unread emails
  Future<List<Email>> getUnreadEmails({int maxResults = 10}) async {
    return listEmails(query: 'is:unread in:inbox', maxResults: maxResults);
  }

  /// Get a specific email by ID
  Future<Email?> getEmail(String emailId, {bool includeBody = true}) async {
    try {
      final format = includeBody ? 'full' : 'metadata';
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/messages/$emailId?format=$format&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to get email: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseEmail(data, includeBody: includeBody);
    } catch (e) {
      debugPrint('Error getting email: $e');
      return null;
    }
  }

  /// Parse email from API response
  Email _parseEmail(Map<String, dynamic> data, {bool includeBody = false}) {
    final payload = data['payload'] as Map<String, dynamic>? ?? {};
    final headers = payload['headers'] as List<dynamic>? ?? [];

    String subject = '(No Subject)';
    String sender = 'Unknown';
    String? to;
    String? date;

    for (final header in headers) {
      final name = header['name'] as String? ?? '';
      final value = header['value'] as String? ?? '';
      switch (name.toLowerCase()) {
        case 'subject':
          subject = value;
          break;
        case 'from':
          sender = value;
          break;
        case 'to':
          to = value;
          break;
        case 'date':
          date = value;
          break;
      }
    }

    String? body;
    String? bodyHtml;
    if (includeBody) {
      final extracted = _extractBody(payload);
      body = extracted.$1;
      bodyHtml = extracted.$2;
    }

    // Extract attachments
    final attachments = _extractAttachments(payload, data['id'] as String);

    final labelIds = (data['labelIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    return Email(
      id: data['id'] as String,
      threadId: data['threadId'] as String,
      subject: subject,
      sender: sender,
      to: to,
      snippet: data['snippet'] as String? ?? '',
      body: body,
      bodyHtml: bodyHtml,
      date: date,
      isUnread: labelIds.contains('UNREAD'),
      labelIds: labelIds,
      attachments: attachments,
    );
  }

  /// Extract attachments from email payload
  List<Attachment> _extractAttachments(Map<String, dynamic> payload, String emailId) {
    final attachments = <Attachment>[];
    _findAttachments(payload, attachments);
    return attachments;
  }

  void _findAttachments(Map<String, dynamic> part, List<Attachment> attachments) {
    final filename = part['filename'] as String?;
    final body = part['body'] as Map<String, dynamic>?;
    final attachmentId = body?['attachmentId'] as String?;
    final size = body?['size'] as int? ?? 0;
    final mimeType = part['mimeType'] as String? ?? 'application/octet-stream';

    // If it has a filename and attachmentId, it's an attachment
    if (filename != null && filename.isNotEmpty && attachmentId != null) {
      attachments.add(Attachment(
        id: attachmentId,
        filename: filename,
        mimeType: mimeType,
        size: size,
      ));
    }

    // Recurse into parts
    final parts = part['parts'] as List<dynamic>?;
    if (parts != null) {
      for (final subPart in parts) {
        _findAttachments(subPart as Map<String, dynamic>, attachments);
      }
    }
  }

  /// Extract body from email payload
  (String?, String?) _extractBody(Map<String, dynamic> payload) {
    String? plainText = _findPartByType(payload, 'text/plain');
    String? htmlContent = _findPartByType(payload, 'text/html');

    // Direct body (no parts)
    if (plainText == null && htmlContent == null) {
      final bodyData = payload['body']?['data'] as String?;
      if (bodyData != null) {
        final content = _decodeBase64Url(bodyData);
        if (content.contains('<html') || content.contains('<body')) {
          return (_htmlToText(content), content);
        }
        return (content, null);
      }
    }

    // If we have HTML but no plain text, convert
    if (htmlContent != null && plainText == null) {
      plainText = _htmlToText(htmlContent);
    }

    return (plainText, htmlContent);
  }

  /// Find and decode a part by MIME type
  String? _findPartByType(Map<String, dynamic> payload, String mimeType) {
    if (payload['mimeType'] == mimeType) {
      final data = payload['body']?['data'] as String?;
      if (data != null) {
        return _decodeBase64Url(data);
      }
    }

    final parts = payload['parts'] as List<dynamic>?;
    if (parts != null) {
      for (final part in parts) {
        final partMap = part as Map<String, dynamic>;
        if (partMap['mimeType'] == mimeType) {
          final data = partMap['body']?['data'] as String?;
          if (data != null) {
            return _decodeBase64Url(data);
          }
        }
        // Recurse into nested parts
        final result = _findPartByType(partMap, mimeType);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  /// Decode base64url encoded string
  String _decodeBase64Url(String data) {
    // Add padding if needed
    var padded = data.replaceAll('-', '+').replaceAll('_', '/');
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    return utf8.decode(base64Decode(padded));
  }

  /// Simple HTML to text conversion
  String _htmlToText(String html) {
    var text = html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'</p>'), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
    return text.trim();
  }

  /// Send an email
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final message = 'To: $to\r\n'
          'Subject: $subject\r\n'
          'Content-Type: text/plain; charset=utf-8\r\n'
          '\r\n'
          '$body';

      final encoded = base64Url.encode(utf8.encode(message));

      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/messages/send'),
        headers: await _headers(),
        body: jsonEncode({'raw': encoded}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Reply to an email
  Future<bool> replyToEmail(Email email, String body) async {
    try {
      final message = 'To: ${email.sender}\r\n'
          'Subject: Re: ${email.subject}\r\n'
          'In-Reply-To: ${email.id}\r\n'
          'References: ${email.id}\r\n'
          'Content-Type: text/plain; charset=utf-8\r\n'
          '\r\n'
          '$body';

      final encoded = base64Url.encode(utf8.encode(message));

      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/messages/send'),
        headers: await _headers(),
        body: jsonEncode({
          'raw': encoded,
          'threadId': email.threadId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error replying to email: $e');
      return false;
    }
  }

  /// Mark email as read
  Future<bool> markAsRead(String emailId) async {
    return _modifyLabels(emailId, removeLabels: ['UNREAD']);
  }

  /// Archive email (remove from inbox)
  Future<bool> archiveEmail(String emailId) async {
    return _modifyLabels(emailId, removeLabels: ['INBOX']);
  }

  /// Delete email (move to trash)
  Future<bool> deleteEmail(String emailId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/messages/$emailId/trash'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting email: $e');
      return false;
    }
  }

  /// Apply a label to an email
  Future<bool> applyLabel(String emailId, String labelName) async {
    final labelId = await _getOrCreateLabelId(labelName);
    if (labelId == null) return false;
    return _modifyLabels(emailId, addLabels: [labelId]);
  }

  /// Remove a label from an email
  Future<bool> removeLabel(String emailId, String labelName) async {
    final labels = await listLabels();
    final label = labels.firstWhere(
      (l) => l.name.toLowerCase() == labelName.toLowerCase(),
      orElse: () => const EmailLabel(id: '', name: ''),
    );
    if (label.id.isEmpty) return false;
    return _modifyLabels(emailId, removeLabels: [label.id]);
  }

  /// Modify email labels
  Future<bool> _modifyLabels(
    String emailId, {
    List<String>? addLabels,
    List<String>? removeLabels,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/messages/$emailId/modify'),
        headers: await _headers(),
        body: jsonEncode({
          if (addLabels != null) 'addLabelIds': addLabels,
          if (removeLabels != null) 'removeLabelIds': removeLabels,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error modifying labels: $e');
      return false;
    }
  }

  /// List all labels
  Future<List<EmailLabel>> listLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/labels'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final labels = data['labels'] as List<dynamic>? ?? [];

      return labels.map((l) => EmailLabel(
        id: l['id'] as String,
        name: l['name'] as String,
        type: l['type'] as String? ?? 'user',
      )).toList();
    } catch (e) {
      debugPrint('Error listing labels: $e');
      return [];
    }
  }

  /// Get or create a label ID
  Future<String?> _getOrCreateLabelId(String labelName) async {
    final labels = await listLabels();
    for (final label in labels) {
      if (label.name.toLowerCase() == labelName.toLowerCase()) {
        return label.id;
      }
    }

    // Create the label
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/labels'),
        headers: await _headers(),
        body: jsonEncode({'name': labelName}),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['id'] as String?;
    } catch (e) {
      debugPrint('Error creating label: $e');
      return null;
    }
  }

  /// Search emails
  Future<List<Email>> searchEmails(String query, {int maxResults = 10}) async {
    return listEmails(query: query, maxResults: maxResults);
  }

  /// Download an attachment and return the file path
  Future<String?> downloadAttachment(String emailId, String attachmentId, String filename) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/messages/$emailId/attachments/$attachmentId'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to download attachment: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final base64Data = data['data'] as String?;
      if (base64Data == null) return null;

      // Decode base64url
      var padded = base64Data.replaceAll('-', '+').replaceAll('_', '/');
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final bytes = base64Decode(padded);

      // Save to temp directory
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      debugPrint('Error downloading attachment: $e');
      return null;
    }
  }
}
