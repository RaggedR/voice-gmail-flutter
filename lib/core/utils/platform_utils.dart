import 'dart:io';

/// Platform detection utilities
class PlatformUtils {
  PlatformUtils._();

  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Check if yabai is available (macOS only)
  static Future<bool> isYabaiAvailable() async {
    if (!isMacOS) return false;
    try {
      final result = await Process.run('which', ['yabai']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
