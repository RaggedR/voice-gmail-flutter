# Review Configuration

## Project Context
Voice-controlled Gmail desktop application for accessibility users.

## Tech Stack
- **Flutter/Dart**: Desktop macOS app
- **Deepgram**: Speech-to-text
- **Anthropic Claude**: AI agent for NLU
- **Gmail API**: Email operations

## Review Focus Areas
- Voice recognition accuracy and wake word handling
- Gmail API error handling and rate limiting
- OAuth token management and security
- Accessibility considerations
- macOS entitlements and permissions
- Riverpod state management patterns

## Code Standards
- Dart: Follow flutter_lints rules
- Models use freezed + json_serializable
- Run `flutter analyze` for linting
- Run `dart run build_runner build` after model changes

## Required Checks
- `flutter analyze` must pass
- No hardcoded credentials
- Proper error handling for API calls
