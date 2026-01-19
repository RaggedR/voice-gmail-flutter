# Research Configuration

## Project Context
Voice-controlled Gmail desktop application for users who cannot use their hands. Uses speech-to-text for input, Claude AI for natural language understanding and tool orchestration, and Flutter for the desktop GUI.

## Tech Stack
- **Flutter/Dart**: Desktop macOS app with Riverpod state management
- **Deepgram**: WebSocket-based speech-to-text
- **Anthropic Claude**: AI agent with tool use for Gmail operations
- **Gmail API**: OAuth2 authentication, email CRUD operations
- **TTS**: Text-to-speech for audio feedback

## Research Priorities
- Speech recognition accuracy and wake word detection
- Deepgram API features and configuration
- Claude tool use patterns and streaming
- Gmail API best practices
- Flutter desktop (macOS) specific features
- Accessibility patterns for voice-first applications

## Preferred Sources
- pub.dev for Flutter/Dart packages
- Deepgram documentation
- Anthropic Claude documentation
- Google Gmail API documentation
- Flutter desktop documentation

## Project Structure Reference
See CLAUDE.md in project root for full architecture and command flow.

## Output Format
Write findings to `RESEARCH.md` with:
- Clear title and date
- Executive summary
- Detailed findings with code examples where applicable
- Recommendations specific to this project's architecture
- References and links to sources
