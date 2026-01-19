import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/utils/html_utils.dart';
import '../../data/email_model.dart';

/// Gmail-style email content view
class EmailContentView extends StatelessWidget {
  final Email? email;
  final ScrollController? scrollController;

  const EmailContentView({
    super.key,
    this.email,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (email == null) {
      return const Center(
        child: Text(
          'Select an email to view its contents.',
          style: TextStyle(
            color: GmailColors.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    final senderName = HtmlUtils.extractSenderName(email!.sender);
    final initials = HtmlUtils.getInitials(senderName);
    final avatarColor = GmailColors.getAvatarColor(senderName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header area
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject
              Text(
                email!.subject,
                style: const TextStyle(
                  fontSize: 18,
                  color: GmailColors.text,
                ),
              ),
              const SizedBox(height: 16),
              // Sender info with avatar
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sender/recipient info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'From: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: GmailColors.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: GmailColors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (email!.to != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                'To: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GmailColors.textSecondary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  HtmlUtils.extractSenderName(email!.to!),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: GmailColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (email!.date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            email!.date!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: GmailColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Attachments
        if (email!.attachments.isNotEmpty) ...[
          const Divider(color: GmailColors.border, height: 1),
          _buildAttachments(),
        ],
        // Divider
        const Divider(color: GmailColors.border, height: 1),
        // Body
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachments() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: GmailColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16, color: GmailColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${email!.attachments.length} attachment${email!.attachments.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: GmailColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: email!.attachments.map((attachment) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: GmailColors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: GmailColors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getFileIcon(attachment.mimeType),
                      size: 20,
                      color: _getFileColor(attachment.mimeType),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.filename,
                          style: const TextStyle(
                            fontSize: 13,
                            color: GmailColors.text,
                          ),
                        ),
                        Text(
                          _formatFileSize(attachment.size),
                          style: const TextStyle(
                            fontSize: 11,
                            color: GmailColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.pink;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('document')) return Colors.blue;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Colors.green;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Colors.orange;
    if (mimeType.startsWith('video/')) return Colors.purple;
    if (mimeType.startsWith('audio/')) return Colors.teal;
    return Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildBody() {
    // Prefer HTML if available
    if (email!.bodyHtml != null && email!.bodyHtml!.isNotEmpty) {
      return Html(
        data: email!.bodyHtml!,
        style: {
          'body': Style(
            fontFamily: 'Helvetica, Arial, sans-serif',
            fontSize: FontSize(14),
            color: GmailColors.text,
            lineHeight: const LineHeight(1.6),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'a': Style(
            color: const Color(0xFF1A73E8),
          ),
        },
      );
    }

    // Fall back to plain text
    final body = email!.body ?? email!.snippet;
    return SelectableText(
      body,
      style: const TextStyle(
        fontSize: 14,
        color: GmailColors.text,
        height: 1.6,
      ),
    );
  }
}
