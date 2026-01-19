// Basic Flutter widget test for Voice Gmail app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_gmail_flutter/app.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: VoiceGmailApp(),
      ),
    );

    // Verify that the app title appears
    expect(find.text('Gmail'), findsWidgets);
  });
}
