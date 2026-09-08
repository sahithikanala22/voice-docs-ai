import 'package:ai_voice_docs/features/history/domain/history_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchesSearch', () {
    test('matches English text by exact word', () {
      expect(matchesSearch('I had a great day', 'great'), isTrue);
    });

    test('matches related word forms, not just exact spelling', () {
      expect(matchesSearch('I had a stressful day at work', 'stress'), isTrue);
      expect(
        matchesSearch('I was stressed about the deadline', 'stress'),
        isTrue,
      );
    });

    test('does not match unrelated text', () {
      expect(matchesSearch('I had a great day', 'stress'), isFalse);
    });

    test('matches regardless of word order', () {
      expect(
        matchesSearch('had a meeting about work stuff', 'work meeting'),
        isTrue,
      );
    });

    // Regression: an ASCII-only tokenizer treats a whole non-Latin-script
    // entry as one giant separator, leaving zero words to match against —
    // this app supports 60+ languages, so that would silently break search
    // for any non-English entry.
    test('matches non-Latin scripts (Telugu)', () {
      const text = 'నేను ఈ రోజు చాలా బాగా అనిపించింది';
      expect(matchesSearch(text, 'బాగా'), isTrue);
      expect(matchesSearch(text, 'చెడు'), isFalse);
    });

    test('matches non-Latin scripts (Hindi)', () {
      const text = 'आज मेरा दिन बहुत अच्छा था';
      expect(matchesSearch(text, 'अच्छा'), isTrue);
    });

    test('empty query matches everything', () {
      expect(matchesSearch('anything at all', ''), isTrue);
    });
  });
}
