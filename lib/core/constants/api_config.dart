/// API configuration constants
class ApiConfig {
  ApiConfig._();

  /// Anthropic API
  static const String anthropicBaseUrl = 'https://api.anthropic.com';
  static const String anthropicApiVersion = '2023-06-01';
  static const String claudeModel = 'claude-opus-4-5-20251101';
  static const int maxTokens = 512;  // Opus needs more room

  /// Gmail API scopes
  static const List<String> gmailScopes = [
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/gmail.compose',
    'https://www.googleapis.com/auth/gmail.send',
  ];

  /// Deepgram API
  static const String deepgramBaseUrl = 'wss://api.deepgram.com/v1/listen';

  /// OAuth callback port
  static const int oauthCallbackPort = 8080;
}
