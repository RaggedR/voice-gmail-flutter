import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../data/email_model.dart';

/// Labels to hide from display (system labels)
const _hiddenLabels = {
  'INBOX', 'SENT', 'DRAFT', 'SPAM', 'TRASH', 'UNREAD',
  'CATEGORY_PERSONAL', 'CATEGORY_SOCIAL', 'CATEGORY_PROMOTIONS',
  'CATEGORY_UPDATES', 'CATEGORY_FORUMS',
};

/// Label display colors
const _labelColors = {
  'IMPORTANT': Color(0xFFD93025),
  'STARRED': Color(0xFFF4B400),
  'CATEGORY_PRIMARY': Color(0xFF1A73E8),
};

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

  /// Build label chips for visible labels
  List<Widget> _buildLabelChips() {
    final visibleLabels = widget.email.labelIds
        .where((label) => !_hiddenLabels.contains(label))
        .take(2) // Show max 2 labels
        .toList();

    if (visibleLabels.isEmpty) return [];

    return visibleLabels.map((label) {
      final color = _labelColors[label] ?? GmailColors.textSecondary;
      final displayName = _formatLabelName(label);

      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Text(
            displayName,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Format label ID to display name
  String _formatLabelName(String label) {
    // Handle common labels
    if (label == 'IMPORTANT') return 'Important';
    if (label == 'STARRED') return '★';
    if (label == 'CATEGORY_PRIMARY') return 'Primary';

    // Handle custom labels (Label_xxx format)
    if (label.startsWith('Label_')) {
      return label.substring(6);
    }

    // Capitalize first letter, lowercase rest
    return label[0].toUpperCase() + label.substring(1).toLowerCase();
  }

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
                    // Subject + Labels row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.subject.length > 40
                                ? '${preview.subject.substring(0, 40)}...'
                                : preview.subject,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: fontWeight,
                              color: GmailColors.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Labels
                        ..._buildLabelChips(),
                      ],
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
