import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_config.dart';

/// Gmail OAuth credentials and token management for desktop
class GmailAuth {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _tokenKey = 'gmail_oauth_token';
  static const String _refreshTokenKey = 'gmail_oauth_refresh_token';
  static const String _expiryKey = 'gmail_oauth_expiry';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  HttpServer? _callbackServer;

  String get clientId => dotenv.env['GMAIL_CLIENT_ID'] ?? '';
  String get clientSecret => dotenv.env['GMAIL_CLIENT_SECRET'] ?? '';

  /// Check if we have valid credentials
  bool get isAuthenticated => _accessToken != null && !_isTokenExpired;

  bool get _isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Get current access token, refreshing if needed
  Future<String?> getAccessToken() async {
    await _loadStoredCredentials();

    if (_accessToken == null) {
      return null;
    }

    if (_isTokenExpired && _refreshToken != null) {
      await _refreshAccessToken();
    }

    return _accessToken;
  }

  /// Load stored credentials from secure storage or token.json
  Future<void> _loadStoredCredentials() async {
    if (_accessToken != null) return;

    // First try to load from Python app's token.json
    try {
      final tokenFile = File('/Users/robin/git/andrew/voice_gmail_flutter/token.json');
      if (await tokenFile.exists()) {
        final contents = await tokenFile.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        _accessToken = data['token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        final expiryStr = data['expiry'] as String?;
        if (expiryStr != null) {
          _tokenExpiry = DateTime.tryParse(expiryStr);
        }
        if (_accessToken != null) {
          debugPrint('Loaded credentials from token.json');
          return;
        }
      }
    } catch (e) {
      debugPrint('Could not load token.json: $e');
    }

    // Fall back to secure storage
    try {
      _accessToken = await _secureStorage.read(key: _tokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final expiryStr = await _secureStorage.read(key: _expiryKey);
      if (expiryStr != null) {
        _tokenExpiry = DateTime.tryParse(expiryStr);
      }
    } catch (e) {
      debugPrint('Error loading stored credentials: $e');
    }
  }

  /// Start OAuth flow
  Future<bool> authenticate() async {
    if (clientId.isEmpty || clientSecret.isEmpty) {
      debugPrint('Gmail OAuth credentials not configured');
      return false;
    }

    try {
      // Start local callback server
      _callbackServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        ApiConfig.oauthCallbackPort,
      );

      final redirectUri = 'http://localhost:${ApiConfig.oauthCallbackPort}';
      final scopes = ApiConfig.gmailScopes.join(' ');

      // Build authorization URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes,
        'access_type': 'offline',
        'prompt': 'consent',
      });

      // Open browser for authorization
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not open browser for OAuth');
        await _callbackServer?.close();
        return false;
      }

      // Wait for callback
      final request = await _callbackServer!.first;
      final code = request.uri.queryParameters['code'];

      // Send response to browser
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
          <html>
            <body style="font-family: Arial; text-align: center; padding: 50px;">
              <h1>Authorization Successful</h1>
              <p>You can close this window and return to the app.</p>
            </body>
          </html>
        ''');
      await request.response.close();
      await _callbackServer?.close();
      _callbackServer = null;

      if (code == null) {
        debugPrint('No authorization code received');
        return false;
      }

      // Exchange code for tokens
      return await _exchangeCodeForTokens(code, redirectUri);
    } catch (e) {
      debugPrint('OAuth error: $e');
      await _callbackServer?.close();
      _callbackServer = null;
      return false;
    }
  }

  /// Exchange authorization code for access/refresh tokens
  Future<bool> _exchangeCodeForTokens(String code, String redirectUri) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Token exchange failed: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }

  /// Refresh access token using refresh token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Token refresh failed: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String?;
      final expiresIn = data['expires_in'] as int? ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // Update token.json file
      try {
        final tokenFile = File('/Users/robin/git/andrew/voice_gmail_flutter/token.json');
        final tokenData = {
          'token': _accessToken,
          'refresh_token': _refreshToken,
          'expiry': _tokenExpiry?.toIso8601String(),
          'client_id': clientId,
          'client_secret': clientSecret,
        };
        await tokenFile.writeAsString(jsonEncode(tokenData));
      } catch (e) {
        debugPrint('Could not update token.json: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  /// Save tokens to token.json file
  Future<void> _saveTokens(Map<String, dynamic> data) async {
    _accessToken = data['access_token'] as String?;
    if (data.containsKey('refresh_token')) {
      _refreshToken = data['refresh_token'] as String?;
    }

    final expiresIn = data['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    // Save to token.json file (skip secure storage - causes macOS issues)
    try {
      final tokenFile = File('/Users/robin/git/andrew/voice_gmail_flutter/token.json');
      final tokenData = {
        'token': _accessToken,
        'refresh_token': _refreshToken,
        'expiry': _tokenExpiry?.toIso8601String(),
        'client_id': clientId,
        'client_secret': clientSecret,
      };
      await tokenFile.writeAsString(jsonEncode(tokenData));
      debugPrint('Saved tokens to token.json');
    } catch (e) {
      debugPrint('Error saving token.json: $e');
    }
  }

  /// Sign out and clear stored credentials
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;

    // Delete token.json
    try {
      final tokenFile = File('/Users/robin/git/andrew/voice_gmail_flutter/token.json');
      if (await tokenFile.exists()) {
        await tokenFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting token.json: $e');
    }
  }

  /// Cancel any pending authentication
  void cancelAuth() {
    _callbackServer?.close();
    _callbackServer = null;
  }
}
