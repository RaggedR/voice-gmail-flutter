/// API configuration constants
class ApiConfig {
  ApiConfig._();

  /// Anthropic API
  static const String anthropicBaseUrl = 'https://api.anthropic.com';
  static const String anthropicApiVersion = '2023-06-01';
  static const String claudeModel = 'claude-3-5-haiku-20241022';
  static const int maxTokens = 256;  // Keep low for fast responses

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
