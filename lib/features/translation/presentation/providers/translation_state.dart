import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

part 'translation_state.freezed.dart';

@freezed
class TranslationState with _$TranslationState {
  const factory TranslationState({
    @Default('') String sourceText,
    @Default('') String translatedText,
    @Default(AppConstants.defaultSourceLanguageCode) String sourceLanguageCode,
    @Default(AppConstants.defaultTargetLanguageCode) String targetLanguageCode,
    @Default(false) bool isTranslating,
    String? errorMessage,
  }) = _TranslationState;
}
