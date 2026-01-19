import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/constants/colors.dart';
import '../../../../main.dart' show terminalCommandController;

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

    // Scroll down
    if (lower.contains('down')) {
      final currentY = _pdfController.scrollOffset.dy;
      final newY = currentY + _scrollAmount;
      print('[PDF] Scrolling down: $currentY -> $newY');
      _pdfController.jumpTo(yOffset: newY);
    }
    // Scroll up
    else if (lower.contains('up')) {
      final currentY = _pdfController.scrollOffset.dy;
      final newY = (currentY - _scrollAmount).clamp(0.0, double.infinity);
      print('[PDF] Scrolling up: $currentY -> $newY');
      _pdfController.jumpTo(yOffset: newY);
    }
    // Close PDF
    else if (lower.contains('close') || lower.contains('exit')) {
      Navigator.of(context).pop();
      print('[PDF] Closed');
    }
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmailColors.background,
      appBar: AppBar(
        backgroundColor: GmailColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: GmailColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filename,
              style: const TextStyle(
                fontSize: 16,
                color: GmailColors.text,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  color: GmailColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out, color: GmailColors.text),
            onPressed: () {
              _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(0.5, 3.0);
            },
          ),
          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in, color: GmailColors.text),
            onPressed: () {
              _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(0.5, 3.0);
            },
          ),
          // Open externally
          IconButton(
            icon: const Icon(Icons.open_in_new, color: GmailColors.text),
            onPressed: () async {
              await Process.run('open', [widget.filePath]);
            },
            tooltip: 'Open in Preview',
          ),
        ],
      ),
      body: SfPdfViewer.file(
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
    );
  }
}
