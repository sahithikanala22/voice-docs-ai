import 'package:translator/translator.dart';

import 'package:ai_voice_docs/core/errors/exceptions.dart';

import '../../domain/translation_result.dart';
import 'translation_provider.dart';

/// Default [TranslationProvider]: calls Google's free, unofficial
/// translate endpoint via the `translator` package. No API key, but does
/// require network access — unlike the on-device speech/TTS providers, this
/// is NOT an offline provider.
class FreeGoogleTranslationProvider implements TranslationProvider {
  final GoogleTranslator _translator = GoogleTranslator();

  /// The `translator` package uses lowercase, hyphen-cased codes
  /// (`zh-cn`, `zh-tw`) while the rest of the app uses locale-style codes
  /// (`zh-CN`, `zh-TW`) shared with the speech/TTS providers — normalize at
  /// this boundary rather than polluting the app-wide language codes.
  String _toProviderCode(String appCode) => appCode.toLowerCase();

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    try {
      final result = await _translator.translate(
        text,
        from: _toProviderCode(sourceLanguageCode),
        to: _toProviderCode(targetLanguageCode),
      );
      return TranslationResult(
        translatedText: result.text,
        detectedSourceLanguageCode: sourceLanguageCode,
      );
    } catch (e) {
      throw TranslationException('Translation failed: $e');
    }
  }
}
