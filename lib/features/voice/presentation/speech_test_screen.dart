import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/providers.dart';

/// Simple screen to test speech-to-text in isolation
class SpeechTestScreen extends ConsumerStatefulWidget {
  const SpeechTestScreen({super.key});

  @override
  ConsumerState<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends ConsumerState<SpeechTestScreen> {
  final List<String> _transcriptions = [];
  bool _isRecording = false;
  String _status = 'Press Start to begin recording';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final speech = ref.read(speechRecognizerProvider);
    final available = await speech.initialize();
    if (available) {
      setState(() {
        _status = 'Ready - Press Start to record (6 seconds)';
      });
    } else {
      setState(() {
        _status = 'Speech recognition not available';
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final speech = ref.read(speechRecognizerProvider);

    setState(() {
      _isRecording = true;
      _status = 'Recording... speak now (6 seconds)';
    });

    await speech.startListening(
      onResult: (text) {
        setState(() {
          _transcriptions.insert(0, text);
          _status = 'Transcribed: "$text"';
        });
      },
      onError: (error) {
        setState(() {
          _status = 'Error: $error';
        });
      },
      onDone: () {
        setState(() {
          _isRecording = false;
          _status = 'Done - Press Start to record again';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Speech-to-Text Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              color: _isRecording ? Colors.red[50] : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 64,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _isRecording ? Colors.red : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isRecording ? null : _startRecording,
                      icon: Icon(_isRecording ? Icons.hourglass_top : Icons.play_arrow),
                      label: Text(_isRecording ? 'Recording...' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Transcriptions list
            const Text(
              'Transcriptions:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: _transcriptions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transcriptions yet.\nSpeak after pressing Start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transcriptions.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _transcriptions[index],
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
