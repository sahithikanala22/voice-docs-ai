import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/features/speech_to_text/data/providers/google_speech_provider.dart';

/// 16kHz mono 16-bit PCM, matching what [GoogleSpeechProvider] actually
/// records and chunks.
const _sampleRate = 16000;
const _bytesPerSample = 2;
const _maxChunkBytes = 55 * _sampleRate * _bytesPerSample; // _maxChunkSeconds = 55

/// [seconds] of PCM — a steady tone, loud enough that chunkRanges' quietest-
/// cut search has real amplitude variation to work with (a few samples per
/// cycle are near zero-crossing, which is what makes a cut point "quiet").
Uint8List _pcmOf(double seconds) {
  final sampleCount = (seconds * _sampleRate).round();
  final bytes = Uint8List(sampleCount * _bytesPerSample);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    final value = (10000 * (i % 100 < 50 ? 1 : -1));
    view.setInt16(i * _bytesPerSample, value, Endian.little);
  }
  return bytes;
}

void main() {
  group('googleLanguageCode', () {
    test('passes a BCP-47 locale code through unchanged', () {
      expect(GoogleSpeechProvider.googleLanguageCode('en-US'), 'en-US');
      expect(GoogleSpeechProvider.googleLanguageCode('hi-IN'), 'hi-IN');
      expect(GoogleSpeechProvider.googleLanguageCode('te-IN'), 'te-IN');
    });

    test('trims surrounding whitespace', () {
      expect(GoogleSpeechProvider.googleLanguageCode(' en-US '), 'en-US');
    });
  });

  group('chunkRanges', () {
    test('a short recording stays in one piece', () {
      final pcm = _pcmOf(2);
      final ranges = GoogleSpeechProvider.chunkRanges(pcm);
      expect(ranges, [(0, pcm.length)]);
    });

    test('produces nothing for an empty recording', () {
      expect(GoogleSpeechProvider.chunkRanges(Uint8List(0)), isEmpty);
    });

    test('splits past the cap, covering the audio with no gaps', () {
      // ~57s of audio — just past the 55s cap, forcing exactly one split.
      final pcm = _pcmOf(57);
      final ranges = GoogleSpeechProvider.chunkRanges(pcm);

      expect(ranges.length, greaterThan(1));
      expect(ranges.first.$1, 0);
      expect(ranges.last.$2, pcm.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2, reason: 'no gap/overlap between consecutive chunks');
      }
    });

    test('never exceeds the ~55s per-request cap', () {
      final pcm = _pcmOf(130);
      final ranges = GoogleSpeechProvider.chunkRanges(pcm);
      for (final (start, end) in ranges) {
        expect(end - start, lessThanOrEqualTo(_maxChunkBytes));
      }
    });

    test('cuts on sample boundaries so no chunk starts mid-sample', () {
      final pcm = _pcmOf(130);
      final ranges = GoogleSpeechProvider.chunkRanges(pcm);
      for (final (start, end) in ranges) {
        expect(start % _bytesPerSample, 0);
        expect(end % _bytesPerSample, 0);
      }
    });
  });
}
