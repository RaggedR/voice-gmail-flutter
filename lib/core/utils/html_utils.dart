/// HTML utility functions
class HtmlUtils {
  HtmlUtils._();

  /// Convert HTML to plain text
  static String htmlToPlainText(String html) {
    // Remove style and script tags with content
    var text = html.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );

    // Replace common tags with appropriate text
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'</p>'), '\n\n');
    text = text.replaceAll(RegExp(r'</div>'), '\n');
    text = text.replaceAll(RegExp(r'</li>'), '\n');
    text = text.replaceAll(RegExp(r'<li[^>]*>'), '• ');

    // Remove remaining tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode common HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');

    return text.trim();
  }

  /// Extract sender name from email address string
  static String extractSenderName(String sender) {
    if (sender.contains('<')) {
      return sender.split('<')[0].trim().replaceAll('"', '');
    }
    return sender;
  }

  /// Get initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Clean email body text for reading
  static String cleanBodyForReading(String body) {
    // Replace URLs with [link]
    var text = body.replaceAll(RegExp(r'https?://\S+'), '[link]');
    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // Truncate if too long
    if (text.length > 2000) {
      text = '${text.substring(0, 2000)}... [truncated]';
    }
    return text.trim();
  }
}
