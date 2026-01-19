import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Yabai window manager client for macOS
class YabaiClient {
  bool? _available;

  /// Check if yabai is available
  Future<bool> get isAvailable async {
    if (_available != null) return _available!;

    if (!Platform.isMacOS) {
      _available = false;
      return false;
    }

    try {
      final result = await Process.run('which', ['yabai']);
      _available = result.exitCode == 0;
      return _available!;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Run a yabai command
  Future<(bool, String)> run(List<String> args) async {
    if (!await isAvailable) {
      return (false, 'Window control requires yabai. Install with: brew install koekeishiya/formulae/yabai');
    }

    try {
      final result = await Process.run(
        'yabai',
        ['-m', ...args],
      ).timeout(const Duration(seconds: 5));

      final output = result.stdout.toString().trim().isNotEmpty
          ? result.stdout.toString().trim()
          : result.stderr.toString().trim();

      return (result.exitCode == 0, output);
    } on TimeoutException {
      return (false, 'Yabai command timed out');
    } catch (e) {
      return (false, 'Error running yabai: $e');
    }
  }

  /// Focus window in a direction
  Future<(bool, String)> focusDirection(String direction) async {
    return run(['window', '--focus', direction]);
  }

  /// Warp (move) window in a direction
  Future<(bool, String)> warpDirection(String direction) async {
    return run(['window', '--warp', direction]);
  }

  /// Resize window by moving an edge
  Future<(bool, String)> resizeWindow(String edge, int dx, int dy) async {
    return run(['window', '--resize', '$edge:$dx:$dy']);
  }

  /// Close the focused window
  Future<(bool, String)> closeWindow() async {
    return run(['window', '--close']);
  }

  /// Minimize the focused window
  Future<(bool, String)> minimizeWindow() async {
    return run(['window', '--minimize']);
  }

  /// Toggle fullscreen for the focused window
  Future<(bool, String)> toggleFullscreen() async {
    return run(['window', '--toggle', 'zoom-fullscreen']);
  }

  /// Toggle floating for the focused window
  Future<(bool, String)> toggleFloat() async {
    return run(['window', '--toggle', 'float']);
  }

  /// Balance all windows in the current space
  Future<(bool, String)> balanceSpace() async {
    return run(['space', '--balance']);
  }

  /// Rotate the window layout
  Future<(bool, String)> rotateSpace(int degrees) async {
    return run(['space', '--rotate', degrees.toString()]);
  }

  /// Query all windows
  Future<(bool, List<Map<String, dynamic>>)> queryWindows() async {
    final (success, output) = await run(['query', '--windows']);
    if (!success) {
      return (false, <Map<String, dynamic>>[]);
    }

    try {
      final windows = (jsonDecode(output) as List<dynamic>)
          .map((w) => w as Map<String, dynamic>)
          .toList();
      return (true, windows);
    } catch (e) {
      debugPrint('Error parsing windows: $e');
      return (false, <Map<String, dynamic>>[]);
    }
  }

  /// Focus a window by application name
  Future<(bool, String)> focusApp(String appName) async {
    final (success, windows) = await queryWindows();
    if (!success) {
      return (false, 'Could not query windows');
    }

    final appLower = appName.toLowerCase();
    for (final window in windows) {
      final app = window['app'] as String? ?? '';
      if (app.toLowerCase().contains(appLower)) {
        final windowId = window['id'];
        if (windowId != null) {
          return run(['window', '--focus', windowId.toString()]);
        }
      }
    }

    return (false, "No window found for app '$appName'");
  }

  /// Get info about the currently focused window
  Future<Map<String, dynamic>?> getFocusedWindow() async {
    final (success, output) = await run(['query', '--windows', '--window']);
    if (!success) {
      return null;
    }

    try {
      return jsonDecode(output) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
