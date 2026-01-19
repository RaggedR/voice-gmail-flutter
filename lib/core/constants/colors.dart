import 'package:flutter/material.dart';

/// Gmail-style color scheme
class GmailColors {
  GmailColors._();

  static const Color background = Color(0xFFF6F8FC);
  static const Color sidebarBackground = Color(0xFFF6F8FC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFFC5221F);
  static const Color primaryLight = Color(0xFFEA4335);
  static const Color text = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textLight = Color(0xFF80868B);
  static const Color border = Color(0xFFE8EAED);
  static const Color selected = Color(0xFFE8F0FE);
  static const Color unread = Color(0xFF202124);
  static const Color hover = Color(0xFFF2F2F2);

  /// Avatar colors for contact initials
  static const List<Color> avatarColors = [
    Color(0xFF1A73E8), // Blue
    Color(0xFF34A853), // Green
    Color(0xFFEA4335), // Red
    Color(0xFFFBBC04), // Yellow
    Color(0xFF9334E6), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
  ];

  /// Get avatar color based on name hash
  static Color getAvatarColor(String name) {
    if (name.isEmpty) return avatarColors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return avatarColors[hash % avatarColors.length];
  }
}
