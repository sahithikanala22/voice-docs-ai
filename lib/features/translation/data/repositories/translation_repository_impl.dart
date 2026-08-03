import '../../domain/translation_repository.dart';
import '../../domain/translation_result.dart';
import '../providers/translation_provider.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  TranslationRepositoryImpl(this._provider);

  final TranslationProvider _provider;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) {
    return _provider.translate(
      text: text,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
  }
}
