# Voice Gmail

A voice-controlled Gmail desktop application for users who cannot use their hands. Built with Flutter, powered by Claude AI.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run -d macos
```

## Command Input

### Voice Control
Say **"Porcupine"** followed by your command:
- "Porcupine, show my inbox"
- "Porcupine, read email 1"
- "Porcupine, scroll down"

The wake word triggers command recognition. Speak naturally after it.

### Terminal Control
Connect via TCP socket to type commands directly:

```bash
nc localhost 9999
```

Then type commands without the wake word:
```
show my inbox
read email 3
scroll down
```

## Available Commands

### Navigation
| Command | Action |
|---------|--------|
| show inbox / show my inbox | Display inbox emails |
| show sent | Display sent emails |
| show starred | Display starred emails |
| read email 1 | Open and display email #1 |
| scroll down | Scroll content down |
| scroll up | Scroll content up |

### Email Actions
| Command | Action |
|---------|--------|
| archive this | Archive current email |
| delete this | Move current email to trash |
| mark as read | Mark current email as read |
| reply saying [message] | Reply to current email |
| send email to [name] about [subject] saying [body] | Compose and send new email |

### Search
| Command | Action |
|---------|--------|
| find emails from [name] | Search by sender |
| search for [query] | General email search |

### Attachments & PDF
| Command | Action |
|---------|--------|
| open attachment | Open first attachment |
| open the pdf | Open PDF attachment |
| close / go back | Close PDF viewer |
| scroll down / scroll up | Scroll within PDF |

### Contacts
| Command | Action |
|---------|--------|
| add [name] to contacts | Save sender to address book |
| show contacts | List all contacts |
| find contact [name] | Look up a contact |

### Window Control (macOS with yabai)
| Command | Action |
|---------|--------|
| focus Safari | Switch to Safari window |
| close window | Close current window |
| fullscreen | Toggle fullscreen |
| move window left | Tile window left |

### Natural Language
You can also ask questions about the current email:
- "Who sent this?"
- "When was this sent?"
- "Are there any attachments?"

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Voice Input   │────▶│   Deepgram   │────▶│  Wake Word      │
│   (Microphone)  │     │   (STT)      │     │  Detection      │
└─────────────────┘     └──────────────┘     └────────┬────────┘
                                                      │
┌─────────────────┐                                   ▼
│ Terminal Input  │──────────────────────────▶┌──────────────┐
│ (nc localhost)  │                           │   Command    │
└─────────────────┘                           │   Stream     │
                                              └──────┬───────┘
                                                     │
                                                     ▼
                              ┌───────────────────────────────────┐
                              │           Claude Agent            │
                              │  ┌─────────────────────────────┐  │
                              │  │      System Prompt +        │  │
                              │  │      Context (current       │  │
                              │  │      email, folder, etc.)   │  │
                              │  └─────────────────────────────┘  │
                              │                                   │
                              │  ┌─────────────────────────────┐  │
                              │  │         Tool Use            │  │
                              │  │  • Gmail Tools (17)         │  │
                              │  │  • Window Tools (10)        │  │
                              │  └─────────────────────────────┘  │
                              └───────────────┬───────────────────┘
                                              │
                        ┌─────────────────────┼─────────────────────┐
                        ▼                     ▼                     ▼
                ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
                │  Gmail API   │     │    Yabai     │     │     TTS      │
                │  Repository  │     │  (Windows)   │     │   Speaker    │
                └──────────────┘     └──────────────┘     └──────────────┘
                        │
                        ▼
                ┌──────────────┐
                │   Flutter    │
                │     GUI      │
                └──────────────┘
```

### Components

**Speech Recognition (Deepgram)**
- Streaming WebSocket connection for real-time transcription
- Wake word detection ("Porcupine" + variations)
- Continuous listening with auto-reconnect

**Claude Agent**
- Natural language understanding
- Context-aware responses (knows current email, folder, etc.)
- Tool orchestration for Gmail and window control

**Gmail Tools**
- `list_emails` - List emails from folder
- `read_email` - Get full email content
- `send_email` - Compose and send
- `reply_to_email` - Reply to thread
- `archive_email` - Archive email
- `delete_email` - Move to trash
- `search_emails` - Search with Gmail query
- `apply_label` / `remove_label` - Label management
- `list_labels` - Show all labels
- Contact management tools

**Window Tools (macOS)**
- `focus_application` - Switch to app
- `close_window` - Close focused window
- `fullscreen_window` - Toggle fullscreen
- `move_window` - Tile windows
- `resize_window` - Adjust size
- `list_windows` - Show open windows

**Text-to-Speech**
- Brief confirmations only (user can see the screen)
- Never reads email content aloud

## Configuration

Create a `.env` file:

```env
ANTHROPIC_API_KEY=sk-ant-...
DEEPGRAM_API_KEY=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

## Requirements

- macOS (primary), Windows, or Linux
- Flutter 3.x
- Microphone access
- Gmail OAuth credentials
- Anthropic API key
- Deepgram API key (for voice)
- yabai (optional, for window control on macOS)

## Project Structure

```
lib/
├── main.dart                 # App entry, TCP server
├── config/providers.dart     # Riverpod providers
├── core/
│   ├── constants/           # Colors, strings, API config
│   └── utils/               # HTML helpers
└── features/
    ├── agent/
    │   ├── data/            # Anthropic client
    │   └── domain/          # EmailAgent, context
    ├── gmail/
    │   ├── data/            # Email model, repository, auth
    │   ├── presentation/    # Screens, widgets
    │   └── tools/           # Gmail tool definitions
    ├── speech/
    │   ├── domain/          # SpeechRecognizer interface
    │   └── implementations/ # Deepgram STT
    ├── tts/                 # Text-to-speech
    ├── window/              # Yabai window control
    └── addressbook/         # Contact storage
```
