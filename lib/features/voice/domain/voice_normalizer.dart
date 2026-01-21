import 'package:dart_phonetics/dart_phonetics.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Handles fuzzy and phonetic matching for voice command transcription errors
class VoiceNormalizer {
  /// Double Metaphone encoder for phonetic matching
  final _metaphone = DoubleMetaphone.withMaxLength(10);

  /// Soundex encoder for simpler phonetic matching
  final _soundex = Soundex();

  /// Number homophones - common STT mishearings for numbers
  static const Map<String, String> _numberHomophones = {
    'to': '2',
    'too': '2',
    'two': '2',
    'for': '4',
    'four': '4',
    'fore': '4',
    'won': '1',
    'one': '1',
    'ate': '8',
    'eight': '8',
    'tree': '3',
    'three': '3',
    'free': '3',
    'sex': '6',
    'six': '6',
    'sicks': '6',
    'heaven': '7',
    'seven': '7',
    'niner': '9',
    'nine': '9',
    'tin': '10',
    'ten': '10',
  };

  /// Normalize transcript text - converts homophones to numbers
  String normalize(String text) {
    var result = text;
    for (final entry in _numberHomophones.entries) {
      // Only replace whole words using word boundaries
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      result = result.replaceAll(pattern, entry.value);
    }
    return result;
  }

  /// Get Double Metaphone encoding for a word
  /// Returns primary and first alternate (if any)
  (String, String?)? getMetaphone(String word) {
    final result = _metaphone.encode(word);
    if (result == null) return null;
    final firstAlt = result.alternates?.isNotEmpty == true
        ? result.alternates!.first
        : null;
    return (result.primary, firstAlt);
  }

  /// Get Soundex encoding for a word
  String getSoundex(String word) {
    final result = _soundex.encode(word);
    return result?.toString() ?? '';
  }

  /// Check if two words match phonetically using Double Metaphone
  /// Returns true if either primary or alternate encodings match
  bool phoneticMatch(String word1, String word2) {
    final enc1 = _metaphone.encode(word1);
    final enc2 = _metaphone.encode(word2);

    if (enc1 == null || enc2 == null) return false;

    // Check primary match
    if (enc1.primary == enc2.primary) return true;

    // Check if enc1.primary matches any of enc2's alternates
    if (enc2.alternates?.contains(enc1.primary) ?? false) return true;

    // Check if any of enc1's alternates match enc2.primary
    if (enc1.alternates?.contains(enc2.primary) ?? false) return true;

    // Check if any alternates match each other
    if (enc1.alternates != null && enc2.alternates != null) {
      for (final alt in enc1.alternates!) {
        if (enc2.alternates!.contains(alt)) return true;
      }
    }

    return false;
  }

  /// Find best phonetic match from a vocabulary list
  /// Returns (match, isPerfect) where isPerfect indicates exact phonetic match
  (String, bool)? phoneticMatchFromList(String input, List<String> vocabulary) {
    if (vocabulary.isEmpty) return null;

    final inputEnc = _metaphone.encode(input);
    if (inputEnc == null) return null;

    // First pass: look for exact phonetic match
    for (final word in vocabulary) {
      final wordEnc = _metaphone.encode(word);
      if (wordEnc == null) continue;

      if (inputEnc.primary == wordEnc.primary ||
          (wordEnc.alternates?.contains(inputEnc.primary) ?? false) ||
          (inputEnc.alternates?.contains(wordEnc.primary) ?? false)) {
        return (word, true);
      }
    }

    // Second pass: look for partial phonetic match (prefix)
    for (final word in vocabulary) {
      final wordEnc = _metaphone.encode(word);
      if (wordEnc == null) continue;

      if (inputEnc.primary.length >= 2 &&
          wordEnc.primary.startsWith(inputEnc.primary.substring(0, 2))) {
        return (word, false);
      }
    }

    return null;
  }

  /// Fuzzy match against a vocabulary list
  /// Returns the best match if score >= cutoff, null otherwise
  String? fuzzyMatch(String input, List<String> vocabulary, {int cutoff = 70}) {
    if (vocabulary.isEmpty) return null;

    final result = extractOne(
      query: input.toLowerCase(),
      choices: vocabulary.map((v) => v.toLowerCase()).toList(),
    );

    if (result.score >= cutoff) {
      // Return the original case version from vocabulary
      final matchIndex = vocabulary.indexWhere(
        (v) => v.toLowerCase() == result.choice,
      );
      return matchIndex >= 0 ? vocabulary[matchIndex] : result.choice;
    }
    return null;
  }

  /// Combined fuzzy + phonetic match
  /// First tries phonetic match, then falls back to fuzzy
  /// Returns (match, method) where method is 'phonetic', 'fuzzy', or null
  (String, String)? combinedMatch(String input, List<String> vocabulary, {int fuzzyCutoff = 70}) {
    if (vocabulary.isEmpty) return null;

    // Try phonetic match first
    final phoneticResult = phoneticMatchFromList(input, vocabulary);
    if (phoneticResult != null && phoneticResult.$2) {
      return (phoneticResult.$1, 'phonetic');
    }

    // Fall back to fuzzy match
    final fuzzyResult = fuzzyMatch(input, vocabulary, cutoff: fuzzyCutoff);
    if (fuzzyResult != null) {
      return (fuzzyResult, 'fuzzy');
    }

    // Try partial phonetic match as last resort
    if (phoneticResult != null) {
      return (phoneticResult.$1, 'phonetic-partial');
    }

    return null;
  }

  /// Fuzzy match a command against known commands
  /// Returns (matched_command, score) or null if no match
  (String, int)? fuzzyMatchCommand(String input, List<String> commands, {int cutoff = 60}) {
    if (commands.isEmpty) return null;

    final result = extractOne(
      query: input.toLowerCase(),
      choices: commands.map((c) => c.toLowerCase()).toList(),
    );

    if (result.score >= cutoff) {
      final matchIndex = commands.indexWhere(
        (c) => c.toLowerCase() == result.choice,
      );
      return (matchIndex >= 0 ? commands[matchIndex] : result.choice, result.score);
    }
    return null;
  }

  /// Find wake word in text using combined fuzzy + phonetic matching
  /// Returns (wakeWord, startIndex, endIndex) or null if not found
  (String, int, int)? findWakeWord(
    String text, {
    String target = 'porcupine',
    int cutoff = 60,
  }) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;

    final targetEnc = _metaphone.encode(target);

    int bestScore = 0;
    int bestStartWord = -1;
    int bestEndWord = -1;
    String bestMatch = '';
    bool foundPhonetic = false;

    // Try single words and pairs of adjacent words
    for (int i = 0; i < words.length; i++) {
      // Single word - check phonetic match first
      final wordEnc = _metaphone.encode(words[i]);
      if (wordEnc != null && targetEnc != null) {
        if (wordEnc.primary == targetEnc.primary ||
            (targetEnc.alternates?.contains(wordEnc.primary) ?? false) ||
            (wordEnc.alternates?.contains(targetEnc.primary) ?? false)) {
          // Phonetic match - prioritize this
          bestScore = 100;
          bestStartWord = i;
          bestEndWord = i;
          bestMatch = words[i];
          foundPhonetic = true;
          break; // Phonetic match is definitive
        }
      }

      // Single word - fuzzy score
      final singleScore = ratio(words[i], target);
      if (singleScore > bestScore && !foundPhonetic) {
        bestScore = singleScore;
        bestStartWord = i;
        bestEndWord = i;
        bestMatch = words[i];
      }

      // Two adjacent words (e.g., "porky pine" -> "porcupine")
      if (i + 1 < words.length) {
        final combined = '${words[i]}${words[i + 1]}';

        // Check phonetic match for combined words
        final combinedEnc = _metaphone.encode(combined);
        if (combinedEnc != null && targetEnc != null) {
          if (combinedEnc.primary == targetEnc.primary ||
              (targetEnc.alternates?.contains(combinedEnc.primary) ?? false)) {
            bestScore = 100;
            bestStartWord = i;
            bestEndWord = i + 1;
            bestMatch = '${words[i]} ${words[i + 1]}';
            foundPhonetic = true;
            break;
          }
        }

        // Fuzzy score for combined
        if (!foundPhonetic) {
          final combinedScore = ratio(combined, target);
          if (combinedScore > bestScore) {
            bestScore = combinedScore;
            bestStartWord = i;
            bestEndWord = i + 1;
            bestMatch = '${words[i]} ${words[i + 1]}';
          }
        }
      }
    }

    if (bestScore >= cutoff && bestStartWord >= 0) {
      // Calculate character indices
      int startIdx = 0;
      int endIdx = 0;
      final lowerText = text.toLowerCase();

      // Find the start position of the matched words
      int wordCount = 0;
      int currentPos = 0;
      while (wordCount < bestStartWord && currentPos < lowerText.length) {
        // Skip whitespace
        while (currentPos < lowerText.length && lowerText[currentPos] == ' ') {
          currentPos++;
        }
        // Skip word
        while (currentPos < lowerText.length && lowerText[currentPos] != ' ') {
          currentPos++;
        }
        wordCount++;
      }
      // Skip leading whitespace
      while (currentPos < lowerText.length && lowerText[currentPos] == ' ') {
        currentPos++;
      }
      startIdx = currentPos;

      // Find the end position
      wordCount = bestStartWord;
      while (wordCount <= bestEndWord && currentPos < lowerText.length) {
        // Skip word
        while (currentPos < lowerText.length && lowerText[currentPos] != ' ') {
          currentPos++;
        }
        wordCount++;
        // Skip whitespace between words (but not after last word)
        if (wordCount <= bestEndWord) {
          while (currentPos < lowerText.length && lowerText[currentPos] == ' ') {
            currentPos++;
          }
        }
      }
      endIdx = currentPos;

      return (bestMatch, startIdx, endIdx);
    }

    return null;
  }

  /// Check if input fuzzy-matches any of the target strings
  bool matchesAny(String input, List<String> targets, {int cutoff = 70}) {
    final inputLower = input.toLowerCase();
    for (final target in targets) {
      final score = ratio(inputLower, target.toLowerCase());
      if (score >= cutoff) return true;
    }
    return false;
  }

  /// Check if input contains a fuzzy match for any of the targets
  bool containsFuzzyMatch(String input, List<String> targets, {int cutoff = 70}) {
    final words = input.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      for (final target in targets) {
        final score = ratio(word, target.toLowerCase());
        if (score >= cutoff) return true;
      }
    }
    return false;
  }

  /// Check if input contains a phonetic match for any of the targets
  bool containsPhoneticMatch(String input, List<String> targets) {
    final words = input.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      for (final target in targets) {
        if (phoneticMatch(word, target)) return true;
      }
    }
    return false;
  }

  /// Combined check: fuzzy OR phonetic match
  bool containsMatch(String input, List<String> targets, {int fuzzyCutoff = 70}) {
    return containsPhoneticMatch(input, targets) ||
           containsFuzzyMatch(input, targets, cutoff: fuzzyCutoff);
  }
}

/// Global instance for convenience
final voiceNormalizer = VoiceNormalizer();
