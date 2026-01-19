import 'yabai_client.dart';

/// Executes window management tools
class WindowExecutor {
  final YabaiClient _client = YabaiClient();

  /// Direction normalization map
  static const _directionMap = {
    'up': 'north',
    'down': 'south',
    'left': 'west',
    'right': 'east',
    'north': 'north',
    'south': 'south',
    'east': 'east',
    'west': 'west',
  };

  /// Resize action map: action -> (edge, dx, dy)
  static const _resizeMap = {
    'grow-left': ('left', -50, 0),
    'grow-right': ('right', 50, 0),
    'grow-up': ('top', 0, -50),
    'grow-down': ('bottom', 0, 50),
    'shrink-left': ('left', 50, 0),
    'shrink-right': ('right', -50, 0),
    'shrink-up': ('top', 0, 50),
    'shrink-down': ('bottom', 0, -50),
    'grow': ('right', 50, 0),
    'shrink': ('right', -50, 0),
  };

  /// Execute a window tool
  Future<String> execute(String toolName, Map<String, dynamic> input) async {
    switch (toolName) {
      case 'focus_window':
        return _focusWindow(input);
      case 'move_window':
        return _moveWindow(input);
      case 'resize_window':
        return _resizeWindow(input);
      case 'close_window':
        return _closeWindow();
      case 'minimize_window':
        return _minimizeWindow();
      case 'fullscreen_window':
        return _fullscreenWindow();
      case 'float_window':
        return _floatWindow();
      case 'list_windows':
        return _listWindows();
      case 'balance_windows':
        return _balanceWindows();
      case 'rotate_layout':
        return _rotateLayout(input);
      default:
        return 'Unknown window tool: $toolName';
    }
  }

  Future<String> _checkAvailable() async {
    if (!await _client.isAvailable) {
      return 'Window control requires yabai. Install with: brew install koekeishiya/formulae/yabai';
    }
    return '';
  }

  Future<String> _focusWindow(Map<String, dynamic> input) async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final appName = input['app_name'] as String?;
    final direction = input['direction'] as String?;

    if (appName != null && appName.isNotEmpty) {
      final (success, msg) = await _client.focusApp(appName);
      if (success) {
        return 'Focused $appName.';
      }
      return msg;
    }

    if (direction != null && direction.isNotEmpty) {
      final normalized = _directionMap[direction.toLowerCase()] ?? direction.toLowerCase();
      final (success, _) = await _client.focusDirection(normalized);
      if (success) {
        return 'Focused window to the $direction.';
      }
      return 'No window to focus in that direction.';
    }

    return 'Please specify a direction (up/down/left/right) or an app name.';
  }

  Future<String> _moveWindow(Map<String, dynamic> input) async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final direction = input['direction'] as String?;
    if (direction == null) {
      return 'Please specify a direction.';
    }

    final normalized = _directionMap[direction.toLowerCase()] ?? direction.toLowerCase();
    final (success, msg) = await _client.warpDirection(normalized);
    if (success) {
      return 'Moved window $direction.';
    }
    return 'Could not move window: $msg';
  }

  Future<String> _resizeWindow(Map<String, dynamic> input) async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final action = input['action'] as String?;
    if (action == null) {
      return 'Please specify a resize action.';
    }

    final actionLower = action.toLowerCase();
    final resize = _resizeMap[actionLower];
    if (resize == null) {
      return 'Unknown resize action. Use: grow-left, grow-right, grow-up, grow-down, shrink-left, shrink-right, shrink-up, shrink-down, grow, or shrink.';
    }

    final (edge, dx, dy) = resize;
    final (success, msg) = await _client.resizeWindow(edge, dx, dy);
    if (success) {
      return 'Window resized ($action).';
    }
    return 'Could not resize window: $msg';
  }

  Future<String> _closeWindow() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, msg) = await _client.closeWindow();
    if (success) {
      return 'Window closed.';
    }
    return 'Could not close window: $msg';
  }

  Future<String> _minimizeWindow() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, msg) = await _client.minimizeWindow();
    if (success) {
      return 'Window minimized.';
    }
    return 'Could not minimize window: $msg';
  }

  Future<String> _fullscreenWindow() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, msg) = await _client.toggleFullscreen();
    if (success) {
      return 'Toggled fullscreen.';
    }
    return 'Could not toggle fullscreen: $msg';
  }

  Future<String> _floatWindow() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, msg) = await _client.toggleFloat();
    if (success) {
      return 'Toggled floating mode.';
    }
    return 'Could not toggle float: $msg';
  }

  Future<String> _listWindows() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, windows) = await _client.queryWindows();
    if (!success) {
      return 'Could not query windows.';
    }

    if (windows.isEmpty) {
      return 'No windows found.';
    }

    // Filter out hidden windows
    final visible = windows.where((w) => !(w['is-hidden'] as bool? ?? false)).toList();
    if (visible.isEmpty) {
      return 'No visible windows found.';
    }

    final buffer = StringBuffer('Found ${visible.length} windows:\n');
    for (final w in visible) {
      final app = w['app'] as String? ?? 'Unknown';
      var title = w['title'] as String? ?? '';
      if (title.length > 50) {
        title = '${title.substring(0, 47)}...';
      }
      final focused = (w['has-focus'] as bool? ?? false) ? ' (focused)' : '';
      if (title.isNotEmpty) {
        buffer.writeln('  - $app: $title$focused');
      } else {
        buffer.writeln('  - $app$focused');
      }
    }

    return buffer.toString();
  }

  Future<String> _balanceWindows() async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    final (success, msg) = await _client.balanceSpace();
    if (success) {
      return 'Windows balanced.';
    }
    return 'Could not balance windows: $msg';
  }

  Future<String> _rotateLayout(Map<String, dynamic> input) async {
    final err = await _checkAvailable();
    if (err.isNotEmpty) return err;

    var degrees = input['degrees'] as int? ?? 90;
    if (![90, 180, 270].contains(degrees)) {
      degrees = 90;
    }

    final (success, msg) = await _client.rotateSpace(degrees);
    if (success) {
      return 'Layout rotated $degrees degrees.';
    }
    return 'Could not rotate layout: $msg';
  }
}
