import 'translation_result.dart';

abstract class TranslationRepository {
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  });
}
