import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/translation/data/providers/translation_provider.dart';
import 'package:ai_voice_docs/features/translation/domain/translation_result.dart';
import 'package:ai_voice_docs/features/translation/presentation/providers/translation_providers.dart';

class FakeTranslationProvider implements TranslationProvider {
  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    return TranslationResult(
      translatedText: text.toUpperCase(),
      detectedSourceLanguageCode: sourceLanguageCode,
    );
  }
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        translationProviderImplProvider.overrideWithValue(FakeTranslationProvider()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('typing debounces then translates and saves to history', () async {
    final controller = container.read(translationControllerProvider.notifier);

    controller.updateSourceText('hello');
    expect(container.read(translationControllerProvider).translatedText, isEmpty);

    await Future.delayed(const Duration(milliseconds: 700));

    final state = container.read(translationControllerProvider);
    expect(state.translatedText, 'HELLO');
    expect(state.isTranslating, isFalse);

    final history = await container.read(historyControllerProvider.future);
    expect(history, hasLength(1));
    expect(history.first.sourceText, 'hello');
    expect(history.first.translatedText, 'HELLO');
  });

  test('swapLanguages swaps text and language codes', () async {
    final controller = container.read(translationControllerProvider.notifier);

    controller.updateSourceText('hi');
    await Future.delayed(const Duration(milliseconds: 700));

    final before = container.read(translationControllerProvider);
    controller.swapLanguages();
    await Future.delayed(const Duration(milliseconds: 700));

    final after = container.read(translationControllerProvider);
    expect(after.sourceLanguageCode, before.targetLanguageCode);
    expect(after.targetLanguageCode, before.sourceLanguageCode);
    expect(after.sourceText, before.translatedText);
  });

  test('clearing empties source and translated text', () async {
    final controller = container.read(translationControllerProvider.notifier);

    controller.updateSourceText('hello');
    await Future.delayed(const Duration(milliseconds: 700));
    controller.clear();

    final state = container.read(translationControllerProvider);
    expect(state.sourceText, isEmpty);
    expect(state.translatedText, isEmpty);
  });
}
