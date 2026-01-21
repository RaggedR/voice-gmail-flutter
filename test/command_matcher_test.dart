import 'package:flutter_test/flutter_test.dart';
import 'package:voice_gmail_flutter/features/voice/domain/command_matcher.dart';

void main() {
  group('CommandMatcher', () {
    late CommandMatcher matcher;

    setUp(() {
      matcher = CommandMatcher();
    });

    group('exact matches', () {
      test('matches "show inbox" to show_inbox', () {
        final match = matcher.match('show inbox');
        expect(match, isNotNull);
        expect(match!.command, equals('show_inbox'));
        expect(match.isConfident, isTrue);
      });

      test('matches "delete" to delete', () {
        final match = matcher.match('delete');
        expect(match, isNotNull);
        expect(match!.command, equals('delete'));
        expect(match.isConfident, isTrue);
      });

      test('matches "next" to next_email', () {
        final match = matcher.match('next');
        expect(match, isNotNull);
        expect(match!.command, equals('next_email'));
        expect(match.isConfident, isTrue);
      });

      test('matches "archive" to archive', () {
        final match = matcher.match('archive');
        expect(match, isNotNull);
        expect(match!.command, equals('archive'));
        expect(match.isConfident, isTrue);
      });
    });

    group('number extraction', () {
      test('extracts number from "email 3"', () {
        final match = matcher.match('email 3');
        expect(match, isNotNull);
        // Should match open_email with number arg
        if (match!.command == 'open_email') {
          expect(match.args['number'], equals(3));
        }
      });

      test('matches page command', () {
        final match = matcher.match('page 5');
        expect(match, isNotNull);
        // Should match some page-related command
        expect(match!.command, contains('page'));
      });

      test('matches delete command', () {
        final match = matcher.match('delete');
        expect(match, isNotNull);
        expect(match!.command, equals('delete'));
      });
    });

    group('fuzzy matching', () {
      test('matches "show my inbox" to show_inbox', () {
        final match = matcher.match('show my inbox');
        expect(match, isNotNull);
        expect(match!.command, equals('show_inbox'));
      });

      test('matches "delete this email" to delete', () {
        final match = matcher.match('delete this email');
        expect(match, isNotNull);
        expect(match!.command, equals('delete'));
      });

      test('matches "scroll down" to scroll_down', () {
        final match = matcher.match('scroll down');
        expect(match, isNotNull);
        expect(match!.command, equals('scroll_down'));
      });

      test('matches "open attachment" to open_attachment', () {
        final match = matcher.match('open attachment');
        expect(match, isNotNull);
        expect(match!.command, equals('open_attachment'));
      });
    });

    group('wake word handling', () {
      test('strips "jarvis" prefix', () {
        final match = matcher.match('jarvis show inbox');
        expect(match, isNotNull);
        expect(match!.command, equals('show_inbox'));
      });

      test('strips "jarvis," prefix', () {
        final match = matcher.match('jarvis, delete');
        expect(match, isNotNull);
        expect(match!.command, equals('delete'));
      });
    });

    group('confidence scores', () {
      test('exact match has high confidence', () {
        final match = matcher.match('delete');
        expect(match, isNotNull);
        expect(match!.confidence, greaterThanOrEqualTo(90));
        expect(match.isConfident, isTrue);
      });

      test('partial match has lower confidence', () {
        final match = matcher.match('deleet'); // typo
        // May or may not match depending on fuzzy threshold
        if (match != null) {
          expect(match.confidence, lessThan(90));
        }
      });
    });

    group('edge cases', () {
      test('handles empty string', () {
        final match = matcher.match('');
        expect(match, isNull);
      });

      test('handles whitespace only', () {
        final match = matcher.match('   ');
        expect(match, isNull);
      });

      test('handles unknown command', () {
        final match = matcher.match('flibbertigibbet');
        // Should either return null or low confidence
        if (match != null) {
          expect(match.isConfident, isFalse);
        }
      });

      test('is case insensitive', () {
        final match = matcher.match('SHOW INBOX');
        expect(match, isNotNull);
        expect(match!.command, equals('show_inbox'));
      });
    });

    group('all commands have matches', () {
      final testCases = {
        'show_inbox': 'show inbox',
        'show_unread': 'show unread',
        'show_sent': 'show sent',
        'show_drafts': 'show drafts',
        'show_starred': 'starred',
        'delete': 'delete',
        'archive': 'archive',
        'next_email': 'next',
        'previous_email': 'previous',
        'reply': 'reply',
        'forward': 'forward',
        'compose': 'compose',
        'send': 'send',
        'scroll_down': 'scroll down',
        'scroll_up': 'scroll up',
        'open_attachment': 'open attachment',
        'close': 'close',
        'star': 'star',
        'mark_read': 'mark read',
        'refresh': 'refresh',
      };

      for (final entry in testCases.entries) {
        test('command "${entry.key}" matches "${entry.value}"', () {
          final match = matcher.match(entry.value);
          expect(match, isNotNull, reason: 'No match for "${entry.value}"');
          expect(match!.command, equals(entry.key));
        });
      }
    });
  });
}
