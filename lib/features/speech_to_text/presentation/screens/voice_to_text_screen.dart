import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/folder_selector_chip.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/share_format_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/todays_reminders_card.dart';
import 'package:ai_voice_docs/features/tasks/presentation/widgets/todays_tasks_card.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../providers/speech_providers.dart';
import '../widgets/animated_mic_button.dart';
import '../widgets/transcript_card.dart';

class VoiceToTextScreen extends ConsumerStatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  ConsumerState<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends ConsumerState<VoiceToTextScreen> {
  Language _language = languageByCode(AppConstants.defaultSourceLanguageCode);
  bool _initializedFromSettings = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    settingsAsync.whenData((settings) {
      if (!_initializedFromSettings) {
        _initializedFromSettings = true;
        _language = languageByCode(settings.sourceLanguageCode);
      }
    });

    final recognition = ref.watch(speechControllerProvider('home'));
    final foldersAsync = ref.watch(folderControllerProvider);
    final currentFolderId = settingsAsync.value?.currentFolderId;
    final currentFolderName = folderNameFor(foldersAsync.value, currentFolderId);

    ref.listen(speechControllerProvider('home'), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
      final wasListening = previous?.isListening ?? false;
      if (wasListening && !next.isListening && next.transcript.trim().isNotEmpty) {
        ref.read(historyControllerProvider.notifier).addEntry(
              HistoryItem.voice(
                text: next.transcript,
                languageCode: _language.code,
                folderId: currentFolderId,
              ),
            );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice to Text'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: LanguageSelectorChip(
                language: _language,
                onTap: () => _pickLanguage(context),
              ),
            ),
          ),
        ],
        bottom: const GradientAppBarUnderline(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              const TodaysRemindersCard(),
              const TodaysTasksCard(),
              Align(
                alignment: Alignment.centerLeft,
                child: FolderSelectorChip(
                  folderName: currentFolderName,
                  onTap: () => _pickFolder(context, currentFolderId),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TranscriptCard(
                  transcript: recognition.transcript,
                  onCopy: () => _copy(recognition.transcript),
                  onClear: () => ref.read(speechControllerProvider('home').notifier).clearTranscript(),
                  onSpeak: () => ref.read(ttsControllerProvider.notifier).speak(
                        recognition.transcript,
                        _language.localeHint,
                      ),
                  onShare: () => showShareFormatSheet(
                    context,
                    HistoryItem.voice(text: recognition.transcript, languageCode: _language.code),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedMicButton(
                isListening: recognition.isListening,
                soundLevel: recognition.soundLevel,
                onTap: () => _toggleListening(recognition.isListening),
              ),
              const SizedBox(height: 12),
              Text(
                recognition.isListening ? 'Listening… tap to stop' : 'Tap to speak',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleListening(bool isListening) async {
    final controller = ref.read(speechControllerProvider('home').notifier);
    if (isListening) {
      await controller.stopListening();
    } else {
      await controller.startListening(_language.localeHint);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(context, 'Copied to clipboard');
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await context.push<Language>(
      '/language-picker',
      extra: {'title': 'Speech language', 'selectedCode': _language.code},
    );
    if (picked != null) {
      setState(() => _language = picked);
    }
  }

  Future<void> _pickFolder(BuildContext context, String? currentFolderId) async {
    final result = await showFolderPicker(context, selectedFolderId: currentFolderId);
    if (result == null) return;
    await ref.read(settingsControllerProvider.notifier).setCurrentFolderId(result.isEmpty ? null : result);
  }
}
