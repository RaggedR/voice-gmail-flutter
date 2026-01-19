import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/providers.dart';
import 'core/constants/colors.dart';
import 'core/constants/strings.dart';
import 'features/gmail/presentation/screens/auth_screen.dart';
import 'features/gmail/presentation/screens/email_screen.dart';
import 'features/speech/presentation/speech_test_screen.dart';

// Set to true to test speech recognition in isolation
const bool kDebugSpeechTest = false;

/// Main application widget
class VoiceGmailApp extends StatelessWidget {
  const VoiceGmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GmailColors.primary,
          brightness: Brightness.light,
        ),
        fontFamily: 'Helvetica',
      ),
      home: const AuthChecker(),
    );
  }
}

/// Widget that checks auth status and shows appropriate screen
class AuthChecker extends ConsumerWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Debug mode: just test speech recognition
    if (kDebugSpeechTest) {
      return const SpeechTestScreen();
    }

    final authStatus = ref.watch(isAuthenticatedProvider);

    return authStatus.when(
      data: (isAuthenticated) {
        if (isAuthenticated) {
          return const EmailScreen();
        }
        return const AuthScreen();
      },
      loading: () => const Scaffold(
        backgroundColor: GmailColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(GmailColors.primary),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: GmailColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: GmailColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(
                  color: GmailColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(isAuthenticatedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
