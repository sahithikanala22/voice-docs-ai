import 'package:freezed_annotation/freezed_annotation.dart';

part 'translation_result.freezed.dart';

@freezed
class TranslationResult with _$TranslationResult {
  const factory TranslationResult({
    required String translatedText,
    required String detectedSourceLanguageCode,
  }) = _TranslationResult;
}
