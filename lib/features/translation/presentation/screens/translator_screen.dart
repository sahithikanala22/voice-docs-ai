import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../providers/translation_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/language_swap_bar.dart';

class TranslatorScreen extends ConsumerStatefulWidget {
  const TranslatorScreen({super.key});

  @override
  ConsumerState<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends ConsumerState<TranslatorScreen> {
  final _sourceController = TextEditingController();
  bool _initializedFromSettings = false;
  String? _lastAutoPlayedText;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    settingsAsync.whenData((settings) {
      if (!_initializedFromSettings) {
        _initializedFromSettings = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(translationControllerProvider.notifier)
            ..setSourceLanguage(settings.sourceLanguageCode)
            ..setTargetLanguage(settings.targetLanguageCode);
        });
      }
    });

    final state = ref.watch(translationControllerProvider);
    final recognition = ref.watch(speechControllerProvider('translator'));

    if (_sourceController.text != state.sourceText && !recognition.isListening) {
      _sourceController.value = _sourceController.value.copyWith(
        text: state.sourceText,
        selection: TextSelection.collapsed(offset: state.sourceText.length),
      );
    }

    ref.listen(speechControllerProvider('translator'), (previous, next) {
      final wasListening = previous?.isListening ?? false;
      if (wasListening && !next.isListening && next.transcript.trim().isNotEmpty) {
        ref.read(translationControllerProvider.notifier).updateSourceText(next.transcript);
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });

    ref.listen(translationControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
      final autoPlay = settingsAsync.value?.autoPlayTranslationTts ?? false;
      if (autoPlay &&
          next.translatedText.isNotEmpty &&
          next.translatedText != previous?.translatedText &&
          next.translatedText != _lastAutoPlayedText) {
        _lastAutoPlayedText = next.translatedText;
        ref
            .read(ttsControllerProvider.notifier)
            .speak(next.translatedText, languageByCode(next.targetLanguageCode).localeHint);
      }
    });

    final sourceLang = languageByCode(state.sourceLanguageCode);
    final targetLang = languageByCode(state.targetLanguageCode);
    final controller = ref.read(translationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Translator')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              LanguageSwapBar(
                source: sourceLang,
                target: targetLang,
                onTapSource: () => _pickLanguage(
                  context,
                  title: 'Translate from',
                  selectedCode: state.sourceLanguageCode,
                  onPicked: controller.setSourceLanguage,
                ),
                onTapTarget: () => _pickLanguage(
                  context,
                  title: 'Translate to',
                  selectedCode: state.targetLanguageCode,
                  onPicked: controller.setTargetLanguage,
                ),
                onSwap: controller.swapLanguages,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _sourceController,
                        onChanged: controller.updateSourceText,
                        maxLines: null,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: recognition.isListening ? 'Listening…' : 'Type or speak to translate',
                          suffixIcon: IconButton(
                            icon: Icon(recognition.isListening ? Icons.stop_circle_rounded : Icons.mic_rounded),
                            onPressed: () => _toggleListening(recognition.isListening, sourceLang.localeHint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (state.isTranslating)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      ChatBubble(
                        text: state.translatedText,
                        languageLabel: targetLang.name,
                        filled: true,
                        onSpeak: state.translatedText.isEmpty
                            ? null
                            : () => ref
                                .read(ttsControllerProvider.notifier)
                                .speak(state.translatedText, targetLang.localeHint),
                        onCopy: state.translatedText.isEmpty ? null : () => _copy(state.translatedText),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.sourceText.isNotEmpty || state.translatedText.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _sourceController.clear();
                      controller.clear();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleListening(bool isListening, String languageCode) async {
    final speechController = ref.read(speechControllerProvider('translator').notifier);
    if (isListening) {
      await speechController.stopListening();
    } else {
      await speechController.startListening(languageCode);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(context, 'Copied to clipboard');
  }

  Future<void> _pickLanguage(
    BuildContext context, {
    required String title,
    required String selectedCode,
    required void Function(String) onPicked,
  }) async {
    final picked = await context.push<Language>(
      '/language-picker',
      extra: {'title': title, 'selectedCode': selectedCode},
    );
    if (picked != null) onPicked(picked.code);
  }
}
