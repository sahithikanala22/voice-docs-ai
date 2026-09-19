import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/features/speech_to_text/data/providers/sarvam_speech_provider.dart';

/// 16kHz mono 16-bit PCM, so one second is 32000 bytes.
const _bytesPerSecond = 16000 * 2;

/// Constant-amplitude PCM, so no sample looks quieter than any other and the
/// silence search can't bias where a cut lands.
Uint8List _pcmOfSeconds(double seconds) {
  final data = Uint8List((seconds * _bytesPerSecond).round());
  final view = ByteData.sublistView(data);
  for (var i = 0; i + 2 <= data.length; i += 2) {
    view.setInt16(i, 8000, Endian.little);
  }
  return data;
}

void main() {
  group('sarvamLanguageCode', () {
    test('maps Indian languages the app offers onto Sarvam codes', () {
      expect(SarvamSpeechProvider.sarvamLanguageCode('hi-IN'), 'hi-IN');
      expect(SarvamSpeechProvider.sarvamLanguageCode('te-IN'), 'te-IN');
      // The app and Sarvam disagree on Odia's code.
      expect(SarvamSpeechProvider.sarvamLanguageCode('or-IN'), 'od-IN');
      // Regions the app uses that Sarvam doesn't offer still map by language.
      expect(SarvamSpeechProvider.sarvamLanguageCode('en-US'), 'en-IN');
      expect(SarvamSpeechProvider.sarvamLanguageCode('ur-PK'), 'ur-IN');
      expect(SarvamSpeechProvider.sarvamLanguageCode('ne-NP'), 'ne-IN');
    });

    test('falls back to auto-detect for languages Sarvam has no code for', () {
      expect(SarvamSpeechProvider.sarvamLanguageCode('ja-JP'), 'unknown');
      expect(SarvamSpeechProvider.sarvamLanguageCode('fr-FR'), 'unknown');
    });
  });

  group('chunkRanges', () {
    test('keeps a short recording in one piece', () {
      final ranges = SarvamSpeechProvider.chunkRanges(_pcmOfSeconds(10));
      expect(ranges, hasLength(1));
      expect(ranges.single, (0, 10 * _bytesPerSecond));
    });

    test('splits past the API limit, covering the audio with no gaps', () {
      final pcm = _pcmOfSeconds(70);
      final ranges = SarvamSpeechProvider.chunkRanges(pcm);

      expect(ranges.length, greaterThan(1));
      expect(ranges.first.$1, 0);
      expect(ranges.last.$2, pcm.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2, reason: 'chunks must be contiguous');
      }
    });

    test('never exceeds Sarvam\'s 30s per-request cap', () {
      for (final seconds in [29.0, 31.0, 60.0, 125.0]) {
        for (final (start, end) in SarvamSpeechProvider.chunkRanges(_pcmOfSeconds(seconds))) {
          expect(
            (end - start) / _bytesPerSecond,
            lessThanOrEqualTo(30.0),
            reason: 'a $seconds s recording produced an over-long chunk',
          );
        }
      }
    });

    test('cuts on sample boundaries so no chunk starts mid-sample', () {
      for (final (start, end) in SarvamSpeechProvider.chunkRanges(_pcmOfSeconds(95))) {
        expect(start.isEven, isTrue);
        expect(end.isEven, isTrue);
      }
    });

    test('produces nothing for an empty recording', () {
      expect(SarvamSpeechProvider.chunkRanges(Uint8List(0)), isEmpty);
    });
  });

  group('toWav', () {
    test('prepends a 44-byte PCM header describing the audio', () {
      final pcm = _pcmOfSeconds(1);
      final wav = SarvamSpeechProvider.toWav(pcm);
      final view = ByteData.sublistView(wav);

      expect(wav.length, pcm.length + 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

      expect(view.getUint32(4, Endian.little), pcm.length + 36, reason: 'RIFF size');
      expect(view.getUint16(20, Endian.little), 1, reason: 'uncompressed PCM');
      expect(view.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(view.getUint32(24, Endian.little), 16000, reason: 'sample rate');
      expect(view.getUint32(28, Endian.little), 32000, reason: 'byte rate');
      expect(view.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bits per sample');
      expect(view.getUint32(40, Endian.little), pcm.length, reason: 'data size');
    });

    test('copies the samples through untouched', () {
      final pcm = _pcmOfSeconds(0.1);
      final wav = SarvamSpeechProvider.toWav(pcm);
      expect(wav.sublist(44), pcm);
    });

    test('handles a slice of a larger buffer', () {
      // chunkRanges hands toWav a sublistView, which carries a non-zero
      // offset into the original recording.
      final full = _pcmOfSeconds(2);
      final slice = Uint8List.sublistView(full, _bytesPerSecond, 2 * _bytesPerSecond);
      final wav = SarvamSpeechProvider.toWav(slice);

      expect(wav.length, slice.length + 44);
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little), slice.length);
      expect(wav.sublist(44), slice);
    });
  });
}
