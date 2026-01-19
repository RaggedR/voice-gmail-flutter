/// Window tool definitions for LLM function calling
const List<Map<String, dynamic>> windowTools = [
  {
    'name': 'focus_window',
    'description': 'Focus a window in a direction (north/south/east/west) or by app name',
    'input_schema': {
      'type': 'object',
      'properties': {
        'direction': {
          'type': 'string',
          'description': 'Direction to focus: north (up), south (down), east (right), west (left)'
        },
        'app_name': {
          'type': 'string',
          'description': "App name to focus (e.g., 'Safari', 'Terminal', 'Chrome')"
        }
      },
      'required': []
    }
  },
  {
    'name': 'move_window',
    'description': 'Move/swap the focused window in a direction',
    'input_schema': {
      'type': 'object',
      'properties': {
        'direction': {
          'type': 'string',
          'description': 'Direction to move: north (up), south (down), east (right), west (left)'
        }
      },
      'required': ['direction']
    }
  },
  {
    'name': 'resize_window',
    'description': 'Resize the focused window by growing or shrinking it',
    'input_schema': {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': "How to resize: 'grow-left', 'grow-right', 'grow-up', 'grow-down', 'shrink-left', 'shrink-right', 'shrink-up', 'shrink-down', or 'grow'/'shrink' for proportional resize"
        }
      },
      'required': ['action']
    }
  },
  {
    'name': 'close_window',
    'description': 'Close the currently focused window',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'minimize_window',
    'description': 'Minimize the currently focused window',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'fullscreen_window',
    'description': 'Toggle fullscreen mode for the currently focused window',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'float_window',
    'description': 'Toggle floating mode for the currently focused window (remove from tiling)',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'list_windows',
    'description': 'List all open windows with their app names',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'balance_windows',
    'description': 'Balance all window sizes in the current space to be equal',
    'input_schema': {
      'type': 'object',
      'properties': {},
      'required': []
    }
  },
  {
    'name': 'rotate_layout',
    'description': 'Rotate the window layout by 90 degrees',
    'input_schema': {
      'type': 'object',
      'properties': {
        'degrees': {
          'type': 'integer',
          'description': 'Degrees to rotate: 90, 180, or 270',
          'default': 90
        }
      },
      'required': []
    }
  }
];

/// Set of window tool names for routing
const Set<String> windowToolNames = {
  'focus_window',
  'move_window',
  'resize_window',
  'close_window',
  'minimize_window',
  'fullscreen_window',
  'float_window',
  'list_windows',
  'balance_windows',
  'rotate_layout',
};
