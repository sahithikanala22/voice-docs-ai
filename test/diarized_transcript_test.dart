import 'package:ai_voice_docs/features/speech_to_text/domain/diarized_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('speakersIn', () {
    test('empty for a plain single-speaker transcript', () {
      expect(speakersIn('Just me talking about my day.'), isEmpty);
    });

    test('finds distinct speakers in order of first appearance', () {
      const transcript =
          'Speaker 1: Hello there\nSpeaker 2: Hi back\nSpeaker 1: Nice to meet you';
      expect(speakersIn(transcript), [1, 2]);
    });
  });

  group('hasMultipleSpeakers', () {
    test('false for a plain transcript', () {
      expect(hasMultipleSpeakers('Just me talking.'), isFalse);
    });

    test('true when two or more speakers are present', () {
      expect(hasMultipleSpeakers('Speaker 1: hi\nSpeaker 2: hey'), isTrue);
    });
  });

  group('keepOnlySpeaker', () {
    test('keeps only the chosen speaker\'s words, dropping the labels', () {
      const transcript =
          'Speaker 1: I had a great day today\n'
          'Speaker 2: That is nice to hear\n'
          'Speaker 1: Thanks for asking';
      expect(
        keepOnlySpeaker(transcript, 1),
        'I had a great day today Thanks for asking',
      );
    });

    test('returns empty string if the chosen speaker never appears', () {
      const transcript = 'Speaker 1: hello\nSpeaker 2: hi';
      expect(keepOnlySpeaker(transcript, 3), isEmpty);
    });
  });
}
