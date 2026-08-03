import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voxi_translate/core/constants/app_constants.dart';
import 'package:voxi_translate/core/errors/exceptions.dart';
import 'package:voxi_translate/features/history/data/history_item.dart';
import 'package:voxi_translate/features/history/presentation/providers/history_providers.dart';

import '../../data/providers/free_google_translation_provider.dart';
import '../../data/providers/translation_provider.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/translation_repository.dart';
import 'translation_state.dart';

/// Swap this override to plug in a different [TranslationProvider] (e.g. the
/// cloud stub) without touching anything else in the feature.
final translationProviderImplProvider = Provider<TranslationProvider>((ref) => FreeGoogleTranslationProvider());

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(ref.watch(translationProviderImplProvider));
});

/// Drives the translator screen: debounced auto-translate as the user types,
/// language swapping, and saving completed translations to history.
final translationControllerProvider =
    NotifierProvider<TranslationController, TranslationState>(TranslationController.new);

class TranslationController extends Notifier<TranslationState> {
  Timer? _debounce;

  @override
  TranslationState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const TranslationState();
  }

  void setSourceLanguage(String code) {
    state = state.copyWith(sourceLanguageCode: code);
    if (state.sourceText.trim().isNotEmpty) _translateNow();
  }

  void setTargetLanguage(String code) {
    state = state.copyWith(targetLanguageCode: code);
    if (state.sourceText.trim().isNotEmpty) _translateNow();
  }

  void swapLanguages() {
    state = state.copyWith(
      sourceLanguageCode: state.targetLanguageCode,
      targetLanguageCode: state.sourceLanguageCode,
      sourceText: state.translatedText,
      translatedText: state.sourceText,
    );
    if (state.sourceText.trim().isNotEmpty) _translateNow();
  }

  void updateSourceText(String text) {
    state = state.copyWith(sourceText: text, errorMessage: null);
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      state = state.copyWith(translatedText: '');
      return;
    }
    _debounce = Timer(AppConstants.translateDebounce, _translateNow);
  }

  void clear() {
    _debounce?.cancel();
    state = state.copyWith(sourceText: '', translatedText: '', errorMessage: null);
  }

  Future<void> _translateNow() async {
    final text = state.sourceText.trim();
    if (text.isEmpty) return;

    state = state.copyWith(isTranslating: true, errorMessage: null);
    try {
      final result = await ref.read(translationRepositoryProvider).translate(
            text: text,
            sourceLanguageCode: state.sourceLanguageCode,
            targetLanguageCode: state.targetLanguageCode,
          );
      state = state.copyWith(isTranslating: false, translatedText: result.translatedText);

      await ref.read(historyControllerProvider.notifier).addEntry(
            HistoryItem.translation(
              sourceText: text,
              translatedText: result.translatedText,
              sourceLanguageCode: state.sourceLanguageCode,
              targetLanguageCode: state.targetLanguageCode,
            ),
          );
    } on TranslationException catch (e) {
      state = state.copyWith(isTranslating: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isTranslating: false, errorMessage: 'Translation failed. Check your connection.');
    }
  }
}
