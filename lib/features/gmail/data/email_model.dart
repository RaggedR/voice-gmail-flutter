import 'package:freezed_annotation/freezed_annotation.dart';

part 'email_model.freezed.dart';
part 'email_model.g.dart';

/// Email attachment
@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    required String filename,
    required String mimeType,
    required int size,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);
}

/// Email model representing a Gmail message
@freezed
class Email with _$Email {
  const factory Email({
    required String id,
    required String threadId,
    required String subject,
    required String sender,
    String? to,  // Recipient - important for sent emails
    required String snippet,
    String? body,
    String? bodyHtml,
    String? date,
    @Default(false) bool isUnread,
    @Default([]) List<String> labelIds,
    @Default([]) List<Attachment> attachments,
  }) = _Email;

  factory Email.fromJson(Map<String, dynamic> json) => _$EmailFromJson(json);
}

/// Simplified email data for display
@freezed
class EmailPreview with _$EmailPreview {
  const factory EmailPreview({
    required String id,
    required String subject,
    required String senderName,
    required String senderEmail,
    required String snippet,
    required String dateFormatted,
    required bool isUnread,
  }) = _EmailPreview;

  factory EmailPreview.fromEmail(Email email) {
    String senderName = email.sender;
    String senderEmail = email.sender;

    if (email.sender.contains('<')) {
      senderName = email.sender.split('<')[0].trim().replaceAll('"', '');
      final match = RegExp(r'<(.+?)>').firstMatch(email.sender);
      if (match != null) {
        senderEmail = match.group(1) ?? email.sender;
      }
    }

    return EmailPreview(
      id: email.id,
      subject: email.subject,
      senderName: senderName,
      senderEmail: senderEmail,
      snippet: email.snippet,
      dateFormatted: _formatDate(email.date),
      isUnread: email.isUnread,
    );
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    // Try to extract just month and day
    final parts = dateStr.split(' ');
    if (parts.length >= 3) {
      return '${parts[1]} ${parts[2]}'; // e.g., "Jan 18"
    }
    return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
  }
}

/// Email label
@freezed
class EmailLabel with _$EmailLabel {
  const factory EmailLabel({
    required String id,
    required String name,
    @Default('user') String type,
  }) = _EmailLabel;

  factory EmailLabel.fromJson(Map<String, dynamic> json) =>
      _$EmailLabelFromJson(json);
}
