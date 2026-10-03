import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/features/speech_to_text/data/providers/whisper_speech_provider.dart';

void main() {
  group('whisperLanguageCode', () {
    test('takes the primary subtag from a full BCP-47 locale hint', () {
      expect(WhisperSpeechProvider.whisperLanguageCode('en-US'), 'en');
      expect(WhisperSpeechProvider.whisperLanguageCode('hi-IN'), 'hi');
      expect(WhisperSpeechProvider.whisperLanguageCode('pt-BR'), 'pt');
    });

    test('handles the app\'s own bare Language.code values Whisper can\'t use as-is', () {
      // zh-CN / zh-TW are the app's own codes, not a locale hint — Whisper
      // doesn't distinguish simplified/traditional, just 'zh'.
      expect(WhisperSpeechProvider.whisperLanguageCode('zh-CN'), 'zh');
      expect(WhisperSpeechProvider.whisperLanguageCode('zh-TW'), 'zh');
    });

    test('an underscore-separated locale is handled the same as a hyphenated one', () {
      expect(WhisperSpeechProvider.whisperLanguageCode('en_US'), 'en');
    });

    test('a bare code with no region passes through lowercased', () {
      expect(WhisperSpeechProvider.whisperLanguageCode('EN'), 'en');
    });

    test('the auto-detect sentinel passes through unchanged', () {
      // whisper.cpp treats the literal string 'auto' as "detect the spoken
      // language instead of assuming one" — this must never be split or
      // altered the way a real locale code is.
      expect(WhisperSpeechProvider.whisperLanguageCode('auto'), 'auto');
    });
  });

  group('stripNonSpeechTokens', () {
    test('a whole-string non-speech marker becomes empty', () {
      expect(WhisperSpeechProvider.stripNonSpeechTokens('[BLANK_AUDIO]'), '');
      expect(WhisperSpeechProvider.stripNonSpeechTokens('(silence)'), '');
      expect(WhisperSpeechProvider.stripNonSpeechTokens('[no speech]'), '');
    });

    test('is case-insensitive and tolerates a space or underscore before AUDIO', () {
      expect(WhisperSpeechProvider.stripNonSpeechTokens('[blank audio]'), '');
      expect(WhisperSpeechProvider.stripNonSpeechTokens('[Blank_Audio]'), '');
    });

    test('a marker mid-sentence is removed, keeping the real words around it', () {
      expect(
        WhisperSpeechProvider.stripNonSpeechTokens('buy milk [BLANK_AUDIO] and eggs'),
        'buy milk and eggs',
      );
    });

    test('real speech with no marker passes through unchanged', () {
      expect(WhisperSpeechProvider.stripNonSpeechTokens('call mom at 5pm'), 'call mom at 5pm');
    });

    test('bracketed text that is not a known non-speech marker is left alone', () {
      // Only the known whisper.cpp non-speech descriptors are stripped —
      // this must never eat a parenthetical the user actually said/wrote.
      expect(WhisperSpeechProvider.stripNonSpeechTokens('call him (urgent)'), 'call him (urgent)');
    });
  });
}
