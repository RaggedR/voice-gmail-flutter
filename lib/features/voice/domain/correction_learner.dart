import 'package:hive_flutter/hive_flutter.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Learns from user corrections to improve STT interpretation over time.
///
/// When a user repeats/rephrases a command, we learn that the first
/// (misheard) version maps to the second (correct) version.
///
/// Example:
///   User says: "delayed amen" → no action
///   User says: "delete email" → action taken
///   We learn: "delayed amen" → "delete email"
///   Next time: "delayed amen" is auto-corrected to "delete email"
class CorrectionLearner {
  static const String _boxName = 'corrections';
  Box<String>? _box;

  // Recent commands for detecting corrections
  final List<_CommandRecord> _recentCommands = [];
  static const int _maxRecentCommands = 5;
  static const Duration _correctionWindow = Duration(seconds: 30);

  /// Initialize the correction learner
  Future<void> initialize() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    print('[CorrectionLearner] Loaded ${_box!.length} learned corrections');
  }

  /// Record a command and check if it's a correction of a previous one
  /// Returns the corrected text if a learned correction exists, otherwise returns input
  Future<String> processCommand(String rawText, {bool wasSuccessful = false}) async {
    await initialize();

    final normalized = _normalize(rawText);
    final now = DateTime.now();

    // First, check if we have a learned correction for this input
    final learned = _findLearnedCorrection(normalized);
    if (learned != null) {
      print('[CorrectionLearner] Applied learned correction: "$rawText" → "$learned"');
      // Record the corrected version
      _recentCommands.add(_CommandRecord(
        original: rawText,
        normalized: normalized,
        correctedTo: learned,
        timestamp: now,
        wasSuccessful: true,
      ));
      _pruneOldCommands();
      return learned;
    }

    // Check if this looks like a correction of a recent failed command
    if (wasSuccessful) {
      _checkForCorrection(normalized, now);
    }

    // Record this command
    _recentCommands.add(_CommandRecord(
      original: rawText,
      normalized: normalized,
      timestamp: now,
      wasSuccessful: wasSuccessful,
    ));
    _pruneOldCommands();

    return rawText;
  }

  /// Mark the most recent command as successful (Claude understood it)
  void markLastCommandSuccessful() {
    if (_recentCommands.isNotEmpty) {
      final last = _recentCommands.last;
      if (!last.wasSuccessful) {
        _recentCommands[_recentCommands.length - 1] = _CommandRecord(
          original: last.original,
          normalized: last.normalized,
          correctedTo: last.correctedTo,
          timestamp: last.timestamp,
          wasSuccessful: true,
        );
        // Now check if this successful command corrects a previous failed one
        _checkForCorrection(last.normalized, last.timestamp);
      }
    }
  }

  /// Check if a successful command is a correction of a recent failed one
  void _checkForCorrection(String successfulNormalized, DateTime now) {
    // Look for recent failed commands that might be corrections
    for (final record in _recentCommands.reversed) {
      // Skip if too old
      if (now.difference(record.timestamp) > _correctionWindow) break;

      // Skip successful commands
      if (record.wasSuccessful) continue;

      // Skip if it's the same command
      if (record.normalized == successfulNormalized) continue;

      // Check if they're similar but different (likely a correction)
      final similarity = ratio(record.normalized, successfulNormalized);

      // If similarity is 40-85%, it's likely a rephrasing/correction
      // Too similar (>85%) = probably the same thing
      // Too different (<40%) = probably unrelated
      if (similarity >= 40 && similarity <= 85) {
        _learnCorrection(record.normalized, successfulNormalized);
        break; // Only learn one correction at a time
      }
    }
  }

  /// Learn a correction mapping
  Future<void> _learnCorrection(String misheard, String correct) async {
    await initialize();

    // Don't learn if we already have this mapping
    if (_box!.containsKey(misheard)) return;

    await _box!.put(misheard, correct);
    print('[CorrectionLearner] Learned: "$misheard" → "$correct"');
  }

  /// Find a learned correction for the given input
  String? _findLearnedCorrection(String normalized) {
    if (_box == null) return null;

    // Exact match
    if (_box!.containsKey(normalized)) {
      return _box!.get(normalized);
    }

    // Fuzzy match against learned corrections
    for (final key in _box!.keys) {
      final similarity = ratio(normalized, key as String);
      if (similarity >= 85) {
        return _box!.get(key);
      }
    }

    return null;
  }

  /// Normalize text for comparison
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')    // Normalize whitespace
        .trim();
  }

  /// Remove old commands from history
  void _pruneOldCommands() {
    final now = DateTime.now();
    _recentCommands.removeWhere(
      (r) => now.difference(r.timestamp) > _correctionWindow
    );
    // Also limit size
    while (_recentCommands.length > _maxRecentCommands) {
      _recentCommands.removeAt(0);
    }
  }

  /// Get all learned corrections (for debugging/display)
  Map<String, String> getAllCorrections() {
    if (_box == null) return {};
    return Map.fromEntries(
      _box!.keys.map((k) => MapEntry(k as String, _box!.get(k)!))
    );
  }

  /// Clear all learned corrections
  Future<void> clearAll() async {
    await initialize();
    await _box!.clear();
    print('[CorrectionLearner] Cleared all corrections');
  }

  /// Manually add a correction (for user-initiated teaching)
  Future<void> addCorrection(String misheard, String correct) async {
    await initialize();
    final normalizedMisheard = _normalize(misheard);
    final normalizedCorrect = _normalize(correct);
    await _box!.put(normalizedMisheard, normalizedCorrect);
    print('[CorrectionLearner] Manually added: "$normalizedMisheard" → "$normalizedCorrect"');
  }
}

/// Record of a recent command
class _CommandRecord {
  final String original;
  final String normalized;
  final String? correctedTo;
  final DateTime timestamp;
  final bool wasSuccessful;

  _CommandRecord({
    required this.original,
    required this.normalized,
    this.correctedTo,
    required this.timestamp,
    required this.wasSuccessful,
  });
}
