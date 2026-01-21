# Vosk Speech Recognition Server

Local Vosk server with **constrained vocabulary** for voice command recognition.

## Why Vosk?

Unlike Deepgram which does free-form transcription, this server only recognizes words from a predefined vocabulary. This means:
- "Jarvis" can't be misheard as "Travis" or "Davis"
- Only valid command words are output
- Much higher accuracy for voice commands

## Setup

```bash
cd vosk_server

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server (downloads model on first run ~50MB)
python server.py
```

## Usage

1. Start the Vosk server: `python server.py`
2. Set `STT_ENGINE=vosk` in your `.env` file
3. Run the Flutter app: `flutter run -d macos`

## Configuration

```bash
# Default port
python server.py --port 8765

# Use a different model
python server.py --model vosk-model-en-us-0.22
```

## Vocabulary

The constrained vocabulary is defined in `vocabulary.py`. It includes:
- Wake word: "jarvis"
- Navigation: "inbox", "email", "unread", "sent", etc.
- Actions: "delete", "archive", "next", "previous", etc.
- Numbers: "one" through "ten"
- Common connecting words

To add new words, edit `vocabulary.py` and restart the server.

## Architecture

```
[Flutter App] --audio--> [WebSocket] ---> [Vosk Server]
                                              |
                                              v
                                    [Constrained Grammar]
                                              |
                                              v
                              [Only valid command words output]
```

## Troubleshooting

**Server not starting:**
- Check Python 3.8+ installed
- Ensure dependencies installed: `pip install -r requirements.txt`

**Model download fails:**
- Download manually from https://alphacephei.com/vosk/models
- Extract to `vosk_server/models/vosk-model-small-en-us-0.15/`

**Flutter can't connect:**
- Ensure server is running on port 8765
- Check firewall settings
