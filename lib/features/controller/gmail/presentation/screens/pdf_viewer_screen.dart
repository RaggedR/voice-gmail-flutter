import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../../core/constants/colors.dart';
import '../../../../../main.dart' show terminalCommandController;
import '../../../../voice/domain/voice_normalizer.dart';

/// Full-screen PDF viewer with continuous scroll
class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String filename;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.filename,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _commandController = TextEditingController();
  StreamSubscription<String>? _commandSubscription;
  int _currentPage = 1;
  int _totalPages = 0;

  // Scroll amount in pixels (roughly one screen minus overlap)
  static const double _scrollAmount = 500.0;

  @override
  void initState() {
    super.initState();
    _commandSubscription = terminalCommandController.stream.listen(_handleCommand);
  }

  void _handleCommand(String command) {
    final lower = command.toLowerCase();
    print('[PDF] Received command: "$command"');

    // Show command in text field
    _commandController.text = command;

    final normalizer = VoiceNormalizer();
    final normalized = normalizer.normalize(lower);

    // Fuzzy match for page commands: "paid", "paged", "page"
    final hasPage = normalizer.containsFuzzyMatch(normalized, ['page'], cutoff: 70) ||
                    normalized.contains('page') || normalized.contains('paid');

    // Fuzzy match for scroll/direction
    final hasDown = normalizer.containsFuzzyMatch(normalized, ['down'], cutoff: 80) ||
                    normalized.contains('down');
    final hasUp = normalizer.containsFuzzyMatch(normalized, ['up'], cutoff: 80) ||
                  normalized.contains('up');
    final hasScroll = normalizer.containsFuzzyMatch(normalized, ['scroll'], cutoff: 70) ||
                      normalized.contains('scroll') || normalized.contains('scrawl');

    // Fuzzy match for close commands
    final hasClose = normalizer.containsFuzzyMatch(normalized, ['close', 'exit', 'back'], cutoff: 75) ||
                     normalized.contains('close') || normalized.contains('exit') || normalized.contains('back');

    // Go to page - extract number from command
    if (hasPage) {
      final pageNum = _extractPageNumber(normalized);
      if (pageNum != null && pageNum >= 1 && pageNum <= _totalPages) {
        _pdfController.jumpToPage(pageNum);
        print('[PDF] Jumping to page $pageNum');
      }
    }
    // Scroll down
    else if (hasDown || (hasScroll && hasDown)) {
      final currentY = _pdfController.scrollOffset.dy;
      final newY = currentY + _scrollAmount;
      print('[PDF] Scrolling down: $currentY -> $newY');
      _pdfController.jumpTo(yOffset: newY);
    }
    // Scroll up
    else if (hasUp || (hasScroll && hasUp)) {
      final currentY = _pdfController.scrollOffset.dy;
      final newY = (currentY - _scrollAmount).clamp(0.0, double.infinity);
      print('[PDF] Scrolling up: $currentY -> $newY');
      _pdfController.jumpTo(yOffset: newY);
    }
    // Close PDF
    else if (hasClose) {
      Navigator.of(context).pop();
      print('[PDF] Closed');
    }
  }

  /// Extract page number from command, handling homophones
  int? _extractPageNumber(String text) {
    // Get text after "page" to avoid matching "to" in "go to page"
    final pageIdx = text.indexOf('page');
    if (pageIdx < 0) return null;
    final afterPage = text.substring(pageIdx + 4).trim();

    // Homophone map for numbers
    const homophones = {
      'one': 1, 'won': 1,
      'two': 2, 'to': 2, 'too': 2,
      'three': 3, 'tree': 3,
      'four': 4, 'for': 4, 'fore': 4,
      'five': 5,
      'six': 6, 'sicks': 6,
      'seven': 7,
      'eight': 8, 'ate': 8,
      'nine': 9,
      'ten': 10,
    };

    // Try to find a digit first (most reliable)
    final digitMatch = RegExp(r'\d+').firstMatch(afterPage);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(0)!);
    }

    // Try to find a number word in text after "page"
    for (final entry in homophones.entries) {
      if (afterPage.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  void _submitCommand() {
    final text = _commandController.text.trim();
    if (text.isNotEmpty) {
      _commandController.clear();
      terminalCommandController.add(text);
    }
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _pdfController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmailColors.background,
      body: Column(
        children: [
          // Header bar with command input
          Container(
            height: 64,
            color: GmailColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: GmailColors.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          color: GmailColors.text,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_totalPages > 0)
                        Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(
                            fontSize: 11,
                            color: GmailColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Command input
                Container(
                  width: 300,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GmailColors.background,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      hintText: 'Command (scroll up/down, close)',
                      hintStyle: TextStyle(
                        color: GmailColors.textLight,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(Icons.mic, size: 18, color: GmailColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (_) => _submitCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                // Zoom controls
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: GmailColors.text, size: 20),
                  onPressed: () {
                    _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(0.5, 3.0);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: GmailColors.text, size: 20),
                  onPressed: () {
                    _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(0.5, 3.0);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: GmailColors.text, size: 20),
                  onPressed: () async {
                    await Process.run('open', [widget.filePath]);
                  },
                  tooltip: 'Open in Preview',
                ),
              ],
            ),
          ),
          // PDF viewer
          Expanded(
            child: SfPdfViewer.file(
              File(widget.filePath),
              controller: _pdfController,
              onDocumentLoaded: (details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                });
              },
              onPageChanged: (details) {
                setState(() {
                  _currentPage = details.newPageNumber;
                });
              },
              pageLayoutMode: PdfPageLayoutMode.continuous,
              scrollDirection: PdfScrollDirection.vertical,
            ),
          ),
        ],
      ),
    );
  }
}
