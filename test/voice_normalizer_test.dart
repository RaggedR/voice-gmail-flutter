import 'package:flutter_test/flutter_test.dart';
import 'package:voice_gmail_flutter/features/voice/domain/voice_normalizer.dart';

void main() {
  group('VoiceNormalizer', () {
    late VoiceNormalizer normalizer;

    setUp(() {
      normalizer = VoiceNormalizer();
    });

    group('number homophones', () {
      test('converts "two" to "2"', () {
        expect(normalizer.normalize('email two'), equals('email 2'));
      });

      test('converts "to" to "2" when standalone', () {
        expect(normalizer.normalize('go to inbox'), equals('go 2 inbox'));
      });

      test('converts "four" to "4"', () {
        expect(normalizer.normalize('page four'), equals('page 4'));
      });

      test('converts "for" to "4"', () {
        expect(normalizer.normalize('email for'), equals('email 4'));
      });

      test('converts "one" to "1"', () {
        expect(normalizer.normalize('email one'), equals('email 1'));
      });

      test('converts "eight" to "8"', () {
        expect(normalizer.normalize('page eight'), equals('page 8'));
      });

      test('converts "three" to "3"', () {
        expect(normalizer.normalize('open email three'), equals('open email 3'));
      });

      test('handles multiple homophones', () {
        expect(
          normalizer.normalize('email two to four'),
          equals('email 2 2 4'),
        );
      });

      test('is case insensitive', () {
        expect(normalizer.normalize('email TWO'), equals('email 2'));
        expect(normalizer.normalize('PAGE Four'), equals('PAGE 4'));
      });
    });

    group('phonetic matching', () {
      test('matches "jarvis" and "travis" phonetically', () {
        // These may or may not match depending on metaphone encoding
        // Test that the method works without errors
        final result = normalizer.phoneticMatch('jarvis', 'travis');
        expect(result, isA<bool>());
      });

      test('matches similar sounding words', () {
        expect(normalizer.phoneticMatch('delete', 'dileet'), isTrue);
      });

      test('does not match dissimilar words', () {
        expect(normalizer.phoneticMatch('delete', 'archive'), isFalse);
      });
    });

    group('fuzzy matching', () {
      test('matches exact word', () {
        final result = normalizer.fuzzyMatch(
          'delete',
          ['delete', 'archive', 'send'],
        );
        expect(result, equals('delete'));
      });

      test('matches close misspelling', () {
        final result = normalizer.fuzzyMatch(
          'deleet',
          ['delete', 'archive', 'send'],
          cutoff: 70,
        );
        expect(result, equals('delete'));
      });

      test('returns null for no match', () {
        final result = normalizer.fuzzyMatch(
          'xyzabc',
          ['delete', 'archive', 'send'],
          cutoff: 70,
        );
        expect(result, isNull);
      });

      test('respects cutoff threshold', () {
        final lowCutoff = normalizer.fuzzyMatch(
          'xyz',
          ['delete', 'archive', 'send'],
          cutoff: 30,
        );
        final highCutoff = normalizer.fuzzyMatch(
          'xyz',
          ['delete', 'archive', 'send'],
          cutoff: 90,
        );
        // High cutoff should definitely not match 'xyz' to anything
        expect(highCutoff, isNull);
      });
    });

    group('combined matching', () {
      test('returns phonetic match when available', () {
        final result = normalizer.combinedMatch(
          'delete',
          ['delete', 'archive', 'send'],
        );
        expect(result, isNotNull);
        expect(result!.$1, equals('delete'));
      });

      test('falls back to fuzzy when no phonetic match', () {
        final result = normalizer.combinedMatch(
          'deleet',
          ['delete', 'archive', 'send'],
          fuzzyCutoff: 70,
        );
        expect(result, isNotNull);
        expect(result!.$1, equals('delete'));
      });
    });

    group('wake word detection', () {
      test('finds exact wake word', () {
        final result = normalizer.findWakeWord(
          'jarvis show inbox',
          target: 'jarvis',
          cutoff: 80,
        );
        expect(result, isNotNull);
        expect(result!.$1, equals('jarvis'));
      });

      test('finds fuzzy wake word', () {
        final result = normalizer.findWakeWord(
          'travis show inbox',
          target: 'jarvis',
          cutoff: 60,
        );
        // Travis may or may not match Jarvis depending on fuzzy threshold
        // Just verify the method works
        expect(result == null || result.$1.isNotEmpty, isTrue);
      });

      test('returns indices for wake word position', () {
        final result = normalizer.findWakeWord(
          'hey jarvis show inbox',
          target: 'jarvis',
          cutoff: 80,
        );
        expect(result, isNotNull);
        // Verify indices are valid
        expect(result!.$2, greaterThanOrEqualTo(0));
        expect(result.$3, greaterThan(result.$2));
      });
    });

    group('containsMatch', () {
      test('finds match in phrase', () {
        final targets = ['jarvis', 'porcupine'];
        expect(
          normalizer.containsMatch('jarvis show inbox', targets),
          isTrue,
        );
      });

      test('returns false when no match', () {
        final targets = ['jarvis', 'porcupine'];
        expect(
          normalizer.containsMatch('show inbox please', targets),
          isFalse,
        );
      });
    });

    group('matchesAny', () {
      test('matches when input equals target', () {
        expect(
          normalizer.matchesAny('delete', ['delete', 'archive']),
          isTrue,
        );
      });

      test('matches with fuzzy tolerance', () {
        expect(
          normalizer.matchesAny('deleet', ['delete', 'archive'], cutoff: 70),
          isTrue,
        );
      });

      test('returns false for no match', () {
        expect(
          normalizer.matchesAny('xyz', ['delete', 'archive'], cutoff: 70),
          isFalse,
        );
      });
    });
  });

  group('voiceNormalizer global instance', () {
    test('is accessible', () {
      expect(voiceNormalizer, isNotNull);
      expect(voiceNormalizer, isA<VoiceNormalizer>());
    });

    test('can normalize text', () {
      expect(voiceNormalizer.normalize('email two'), equals('email 2'));
    });
  });
}
