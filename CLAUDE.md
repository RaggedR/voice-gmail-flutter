# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voice-controlled Gmail desktop application for users who cannot use their hands. Uses Deepgram for speech-to-text, Claude AI for natural language understanding and tool orchestration, and Flutter for the desktop GUI.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (macOS primary target)
flutter run -d macos

# Regenerate freezed/json_serializable code after model changes
dart run build_runner build --delete-conflicting-outputs

# Build release
flutter build macos
```

## Testing Commands via Terminal

The app runs a TCP server on port 9999 for command input:
```bash
nc localhost 9999
```
Type commands directly without wake word: `show my inbox`, `read email 1`, `scroll down`

## Architecture

### Command Flow
1. **Input**: Voice (Deepgram WebSocket) or terminal (TCP socket on 9999)
2. **Wake Word**: Voice input requires "Porcupine" prefix; terminal input does not
3. **Stream**: Commands broadcast via `terminalCommandController` in `main.dart`
4. **Agent**: `EmailAgent` receives commands with `AgentContext` (current email, folder, email list)
5. **Claude**: Anthropic API with tool definitions for Gmail (17 tools) and window control (10 tools)
6. **Execution**: Tool results update state via Riverpod providers and `GuiCallback`
7. **Response**: Brief TTS confirmation (user can see screen, never reads content aloud)

### Key Components

**Agent Layer** (`lib/features/agent/`)
- `AnthropicClient`: HTTP client for Claude API with streaming support (`createMessageStreamWithTools`)
- `EmailAgent`: Manages conversation history, routes tool calls, maintains `AgentContext`
- System prompt in `email_agent.dart` defines ultra-brief response style

**Tool Definitions** (`lib/features/*/tools/`)
- `gmail_tools.dart`: 17 Gmail tools (list, read, send, archive, delete, search, labels, contacts)
- `window_tools.dart`: 10 yabai window tools (focus, move, resize, close, fullscreen)
- Tools are JSON schemas passed to Claude's tool_use capability

**State Management** (`lib/config/providers.dart`)
- All Riverpod providers in single file
- `emailAgentProvider` connects agent to GUI via `GuiCallback`
- Key state: `currentEmailsProvider`, `selectedEmailProvider`, `currentFolderProvider`

**Speech** (`lib/features/speech/`)
- `SpeechRecognizer` interface with `DeepgramSpeechRecognizer` and `PlatformSpeechRecognizer`
- Wake word variations in `email_screen.dart` (`kWakeWords` list) for Deepgram mishearings of "porcupine"

### Data Models

Models use `freezed` + `json_serializable`. After changing models run build_runner.

Key models:
- `Email` in `email_model.dart` (id, threadId, subject, sender, to, body, bodyHtml, attachments)
- `Contact` in `addressbook.dart`

## Configuration

Required `.env` file:
```env
ANTHROPIC_API_KEY=sk-ant-...
DEEPGRAM_API_KEY=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
STT_ENGINE=deepgram  # or 'platform'
```

## Important Patterns

- **Local vs Agent Commands**: Scroll commands handled locally in `email_screen.dart` for speed; all other commands go to Claude
- **GUI Updates**: Agent calls `_onGuiUpdate(action, data)` which updates Riverpod providers
- **Streaming**: `AnthropicClient.createMessageStreamWithTools()` yields `StreamEvent` (TextDelta, ToolUseEvent, MessageEnd)
- **Wake Word Matching**: Fuzzy matching against `kWakeWords` list to handle Deepgram variations

## macOS Permissions

Required entitlements in `macos/Runner/DebugProfile.entitlements`:
- `com.apple.security.network.client` - API access
- `com.apple.security.device.audio-input` - Microphone access
