import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../data/email_model.dart';

/// Gmail-style email list item widget
class EmailListItem extends StatefulWidget {
  final Email email;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const EmailListItem({
    super.key,
    required this.email,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<EmailListItem> createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final preview = EmailPreview.fromEmail(widget.email);
    final fontWeight = widget.email.isUnread ? FontWeight.bold : FontWeight.normal;

    final backgroundColor = widget.isSelected
        ? GmailColors.selected
        : _isHovered
            ? GmailColors.hover
            : GmailColors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(color: GmailColors.border, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email number
              SizedBox(
                width: 28,
                child: Text(
                  '${widget.index}.',
                  style: TextStyle(
                    fontSize: 11,
                    color: GmailColors.textLight,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name
                    Text(
                      preview.senderName.length > 30
                          ? '${preview.senderName.substring(0, 30)}...'
                          : preview.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: fontWeight,
                        color: GmailColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subject
                    Text(
                      preview.subject.length > 50
                          ? '${preview.subject.substring(0, 50)}...'
                          : preview.subject,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: fontWeight,
                        color: GmailColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Snippet
                    Text(
                      preview.snippet.length > 60
                          ? '${preview.snippet.substring(0, 60)}...'
                          : preview.snippet,
                      style: TextStyle(
                        fontSize: 11,
                        color: GmailColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Date
              if (preview.dateFormatted.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    preview.dateFormatted,
                    style: TextStyle(
                      fontSize: 10,
                      color: GmailColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
