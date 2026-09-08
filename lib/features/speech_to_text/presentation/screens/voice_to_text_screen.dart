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
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/on_this_day_card.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/share_format_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/template_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/templated_entry_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/todays_reminders_card.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../../domain/diarized_transcript.dart';
import '../providers/speech_providers.dart';
import '../widgets/animated_mic_button.dart';
import '../widgets/transcript_card.dart';

/// The transcript card's fixed height — guarantees the full recognized text
/// is always visible in a generous, predictable area regardless of how many
/// cards (memories, reminders) are stacked above it. If the page's total
/// content is taller than the screen, the page scrolls; the transcript
/// itself never shrinks to accommodate that.
const _transcriptCardHeight = 300.0;

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

  @override
  void initState() {
    super.initState();
    // Covers both a cold start (app wasn't running) and a tap while the app
    // is already alive in the background — the shell keeps this screen's
    // state around the whole time, so one subscription handles both cases.
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetUri,
    );
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri?.host != 'record' || !mounted) return;
    // Always call go(), even if this tab is already showing — harmless when
    // already here, but necessary to bring this branch to the front of the
    // indexed stack when another tab was open when the widget was tapped.
    context.go('/');
    final recognition = ref.read(speechControllerProvider('home'));
    if (!recognition.isListening) {
      ref
          .read(speechControllerProvider('home').notifier)
          .startListening(_language.localeHint);
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

  /// Saves [transcript] as a new entry — but if Google Cloud's diarization
  /// found more than one speaker, asks which one is the user first, so a
  /// recording with someone else talking nearby doesn't save their words
  /// mixed in with the user's own entry.
  Future<void> _saveRecording(String transcript, String? folderId) async {
    var finalText = transcript;
    final speakers = speakersIn(transcript);
    if (speakers.length > 1) {
      final chosen = await _pickMySpeaker(speakers);
      if (!mounted) return;
      if (chosen != null) {
        finalText = keepOnlySpeaker(transcript, chosen);
      }
    }

    await ref
        .read(historyControllerProvider.notifier)
        .addEntry(
          HistoryItem.voice(
            text: finalText,
            languageCode: _language.code,
            folderId: folderId,
            timestamp: _entryTimestamp,
          ),
        );
  }

  Future<int?> _pickMySpeaker(List<int> speakers) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Multiple speakers detected'),
        content: const Text(
          'This recording picked up more than one voice. Which one is you? '
          'The others will be left out of this entry.',
        ),
        actions: [
          for (final speaker in speakers)
            TextButton(
              onPressed: () => Navigator.pop(context, speaker),
              child: Text('Speaker $speaker'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Keep everyone'),
          ),
        ],
      ),
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
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
      final wasListening = previous?.isListening ?? false;
      if (wasListening &&
          !next.isListening &&
          next.transcript.trim().isNotEmpty) {
        unawaited(_saveRecording(next.transcript, currentFolderId));
        // Back to today for the next recording — picking a past date is a
        // one-off backdate, not a standing mode this screen stays in.
        if (!DateUtils.isSameDay(_selectedDate, DateTime.now())) {
          setState(() => _selectedDate = DateUtils.dateOnly(DateTime.now()));
        }
      }
    });

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
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
      body: PaperBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Capped so a growing stack of cards (memories, reminders)
                // can't push the transcript/mic far down the page — it
                // scrolls internally instead. Forced to full width regardless
                // of each card's own shrink-wrap behavior, now that the outer
                // column left-aligns instead of centering.
                SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        children: const [
                          OnThisDayCard(),
                          TodaysRemindersCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New entry',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FolderSelectorChip(
                      folderName: currentFolderName,
                      onTap: () => _pickFolder(context, currentFolderId),
                    ),
                    DateSelectorChip(
                      label: DateUtils.isSameDay(_selectedDate, DateTime.now())
                          ? 'Today'
                          : DateFormat('MMM d, yyyy').format(_selectedDate),
                      onTap: () => _pickDate(context),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.auto_stories_rounded, size: 18),
                      label: const Text('Template'),
                      onPressed: () => _useTemplate(context, currentFolderId),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _transcriptCardHeight,
                  child: TranscriptCard(
                    transcript: recognition.transcript,
                    isListening: recognition.isListening,
                    onCopy: () => _copy(recognition.transcript),
                    onClear: () => ref
                        .read(speechControllerProvider('home').notifier)
                        .clearTranscript(),
                    onSpeak: () => ref
                        .read(ttsControllerProvider.notifier)
                        .speak(recognition.transcript, _language.localeHint),
                    onShare: () => showShareFormatSheet(
                      context,
                      HistoryItem.voice(
                        text: recognition.transcript,
                        languageCode: _language.code,
                        timestamp: _entryTimestamp,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: AnimatedMicButton(
                    isListening: recognition.isListening,
                    soundLevel: recognition.soundLevel,
                    onTap: () => _toggleListening(recognition.isListening),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    recognition.isListening
                        ? 'Listening… tap to stop'
                        : 'Tap to speak',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
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
