import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/date_selector_chip.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/core/widgets/folder_selector_chip.dart';

import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';

import 'package:ai_voice_docs/features/history/presentation/widgets/share_format_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/template_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/templated_entry_sheet.dart';

import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../../domain/speech_engine.dart';
import '../providers/speech_providers.dart';
import '../widgets/voice_recording_panel.dart';
import 'package:ai_voice_docs/core/widgets/brand_widgets.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_detail_sheet.dart';
import 'package:ai_voice_docs/features/history/domain/entry_summary.dart';
import '../widgets/transcript_card.dart';

/// The transcript card's fixed height — guarantees the full recognized text
/// is always visible in a generous, predictable area regardless of how many
/// cards (memories, reminders) are stacked above it. If the page's total
/// content is taller than the screen, the page scrolls; the transcript
/// itself never shrinks to accommodate that.

class VoiceToTextScreen extends ConsumerStatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  ConsumerState<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends ConsumerState<VoiceToTextScreen> {
  Language _language = languageByCode(AppConstants.defaultSourceLanguageCode);
  bool _initializedFromSettings = false;
  StreamSubscription<Uri?>? _widgetClickSubscription;

  /// The day a new recording should be filed under — always today unless
  /// explicitly backdated via [_pickDate]. Capped at today (never the
  /// future), same rule as the Calendar tab's "Add entry" sheet.
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime _recordingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Covers both a cold start (app wasn't running) and a tap while the app
    // is already alive in the background — the shell keeps this screen's
    // state around the whole time, so one subscription handles both cases.
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleWidgetUri)
        .catchError((Object _) {});
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetUri,
      onError: (Object _) {},
    );
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri?.host != 'record' ||
        !mounted ||
        ref.read(appLockControllerProvider).value?.isUnlocked != true) {
      return;
    }
    // Always call go(), even if this tab is already showing — harmless when
    // already here, but necessary to bring this branch to the front of the
    // indexed stack when another tab was open when the widget was tapped.
    context.go('/');
    final recognition = ref.read(speechControllerProvider('home'));
    if (!recognition.isListening) {
      ref
          .read(speechControllerProvider('home').notifier)
          .startListening(
            _language.localeHint,
            languageCode: _language.code,
            folderId: ref
                .read(settingsControllerProvider)
                .value
                ?.currentFolderId,
            timestamp: _entryTimestamp,
          );
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  /// Today's entries keep the exact current time; a backdated entry defaults
  /// to noon on that day since the actual time of day isn't known — same
  /// convention as the Calendar tab's "Add entry" sheet.
  DateTime get _entryTimestamp {
    final now = DateTime.now();
    if (DateUtils.isSameDay(_selectedDate, now)) return now;
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      12,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateUtils.dateOnly(now),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateUtils.dateOnly(picked));
    }
  }

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
    final currentFolderName = folderNameFor(
      foldersAsync.value,
      currentFolderId,
    );

    ref.listen(speechControllerProvider('home'), (previous, next) {
      if (previous?.isListening == true &&
          !next.isListening &&
          !DateUtils.isSameDay(_selectedDate, DateTime.now())) {
        setState(() => _selectedDate = DateUtils.dateOnly(DateTime.now()));
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final active = recognition.isListening || recognition.isProcessing;
    final recent =
        ref.watch(historyControllerProvider).value ?? const <HistoryItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppTitle(),
        actions: [
          IconButton(
            tooltip: 'Use a template',
            icon: const Icon(Icons.article_outlined),
            onPressed: active
                ? null
                : () => _useTemplate(context, currentFolderId),
          ),
          const SettingsAction(),
        ],
      ),
      bottomNavigationBar: active
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: FilledButton.icon(
                  onPressed: recognition.isProcessing
                      ? null
                      : () => _toggleListening(true),
                  icon: recognition.isProcessing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_rounded),
                  label: Text(
                    recognition.isProcessing
                        ? 'Transcribing and saving…'
                        : 'Stop recording',
                  ),
                ),
              ),
            )
          : null,
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const PageIntroduction(title: "What's on your mind?"),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: active
                        ? null
                        : () => context.push('/meeting-recorder'),
                    icon: const Icon(Icons.mic_external_on_outlined),
                    label: const Text('Record meeting'),
                  ),
                  TextButton.icon(
                    onPressed: active ? null : () => context.push('/settings'),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('Whisper — Free Offline'),
                  ),
                  TextButton.icon(
                    onPressed: active
                        ? null
                        : () => context.push('/recover-recordings'),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('Saved recordings'),
                  ),
                ],
              ),
              VoiceRecordingPanel(
                phase: recognition.phase,
                audioSaved: recognition.audioSaved,
                listening: recognition.isListening,
                processing: recognition.isProcessing,
                level: recognition.soundLevel,
                onTap: () => _toggleListening(recognition.isListening),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DateSelectorChip(
                    label: DateUtils.isSameDay(_selectedDate, DateTime.now())
                        ? 'Today · ${DateFormat('d MMM').format(_selectedDate)}'
                        : DateFormat('d MMM yyyy').format(_selectedDate),
                    onTap: () {
                      if (!active) _pickDate(context);
                    },
                  ),
                  LanguageSelectorChip(
                    language: _language,
                    onTap: () {
                      if (!active) _pickLanguage(context);
                    },
                  ),
                  FolderSelectorChip(
                    folderName: currentFolderName,
                    onTap: () {
                      if (!active) _pickFolder(context, currentFolderId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (settingsAsync.value?.speechEngine ?? SpeechEngine.onDevice)
                    .privacyDescription,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (recognition.transcript.isNotEmpty || active) ...[
                const SizedBox(height: 20),
                if (!active && recognition.errorMessage == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saved to History · ${DateFormat('d MMM').format(_recordingDate)}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 310,
                  child: TranscriptCard(
                    transcript: recognition.transcript,
                    isListening: recognition.isListening,
                    onCopy: () => _copy(recognition.transcript),
                    onClear: () => ref
                        .read(speechControllerProvider('home').notifier)
                        .clearTranscript(),
                    onSpeak: () {
                      final controller = ref.read(
                        ttsControllerProvider.notifier,
                      );
                      if (ref.read(ttsControllerProvider)) {
                        controller.stop();
                      } else {
                        controller.speak(
                          recognition.transcript,
                          _language.localeHint,
                        );
                      }
                    },
                    onShare: () => showShareFormatSheet(
                      context,
                      HistoryItem.voice(
                        text: recognition.transcript,
                        languageCode: _language.code,
                        timestamp: _recordingDate,
                      ),
                    ),
                  ),
                ),
              ],
              if (!active) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent recordings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/history'),
                      child: const Text('View history'),
                    ),
                  ],
                ),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Your saved words will appear here.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                for (final item in recent.take(3))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF080A12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF42CAE8),
                        ),
                      ),
                      title: Text(
                        entrySummary(item.sourceText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('d MMM · h:mm a').format(item.timestamp)} · Saved',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showHistoryDetailSheet(context, ref, item),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleListening(bool isListening) async {
    if (ref.read(speechControllerProvider('home')).isProcessing) return;
    final controller = ref.read(speechControllerProvider('home').notifier);
    if (isListening) {
      await controller.stopListening();
      if (mounted) {
        setState(() => _selectedDate = DateUtils.dateOnly(DateTime.now()));
      }
    } else {
      _recordingDate = _entryTimestamp;
      await controller.startListening(
        _language.localeHint,
        languageCode: _language.code,
        folderId: ref.read(settingsControllerProvider).value?.currentFolderId,
        timestamp: _recordingDate,
      );
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

  Future<void> _pickFolder(
    BuildContext context,
    String? currentFolderId,
  ) async {
    final result = await showFolderPicker(
      context,
      selectedFolderId: currentFolderId,
    );
    if (result == null) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .setCurrentFolderId(result.isEmpty ? null : result);
  }

  Future<void> _useTemplate(
    BuildContext context,
    String? currentFolderId,
  ) async {
    final template = await showTemplatePicker(context);
    if (template == null || !context.mounted) return;
    await showTemplatedEntrySheet(
      context,
      template: template,
      date: _entryTimestamp,
      folderId: currentFolderId,
    );
  }
}
