import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Global stream controller for terminal commands
final terminalCommandController = StreamController<String>.broadcast();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Listen for terminal input (stdin)
  _startTerminalInput();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  // Configure window
  const windowOptions = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(900, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Gmail Voice',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: VoiceGmailApp(),
    ),
  );
}

/// Start a TCP server for command input
/// Connect with: nc localhost 9999
void _startTerminalInput() {
  const port = 9999;

  ServerSocket.bind(InternetAddress.loopbackIPv4, port).then((server) {
    print('\n[Command server running on port $port]');
    print('[Connect with: nc localhost $port]\n');

    server.listen((socket) {
      print('[Client connected]');
      socket.write('Gmail Voice - type commands:\n');

      var buffer = '';
      socket.listen(
        (data) {
          buffer += String.fromCharCodes(data);
          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final command = buffer.substring(0, idx).trim();
            buffer = buffer.substring(idx + 1);
            if (command.isNotEmpty) {
              print('[CMD] Processing: "$command"');
              terminalCommandController.add(command);
              socket.write('> $command\n');
            }
          }
        },
        onDone: () => print('[Client disconnected]'),
        onError: (e) {},
      );
    });
  }).catchError((e) {
    print('[Could not start command server: $e]');
  });
}
