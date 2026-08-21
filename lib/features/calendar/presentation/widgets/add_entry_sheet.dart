import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/folder_selector_chip.dart';
import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';

/// Session tag for this sheet's mic field — distinct from 'home' (and any
/// other screen) so this sheet's dictation never leaks state into, or out
/// of, another screen's live transcript.
const _sourceSessionTag = 'add-entry-source';

/// Bottom sheet for manually adding a history entry on any day — past dates
/// backfill something you did offline instead of only ever capturing "now"
/// via the mic; future dates work like a planned event, and can carry a
/// reminder. The text field can be typed or dictated.
Future<void> showAddEntrySheet(BuildContext context, {required DateTime initialDate}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddEntrySheet(initialDate: initialDate),
  );
}

class _AddEntrySheet extends ConsumerStatefulWidget {
  const _AddEntrySheet({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _sourceTextController = TextEditingController();

  late DateTime _date;
  late Language _sourceLanguage;
  String? _folderId;
  bool _initializedFromSettings = false;
  bool _reminderEnabled = false;
  DateTime? _reminderAt;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    // Same-day entries keep the current time; backdated ones default to
    // noon rather than implying a specific (unknowable) time of day.
    final sameDay = DateUtils.isSameDay(widget.initialDate, DateTime.now());
    _date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      sameDay ? now.hour : 12,
      sameDay ? now.minute : 0,
    );
    _sourceLanguage = languageByCode(AppConstants.defaultSourceLanguageCode);
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    settingsAsync.whenData((settings) {
      if (!_initializedFromSettings) {
        _initializedFromSettings = true;
        _sourceLanguage = languageByCode(settings.sourceLanguageCode);
      }
    });
    final foldersAsync = ref.watch(folderControllerProvider);
    final folderName = folderNameFor(foldersAsync.value, _folderId);

    final sourceRecognition = ref.watch(speechControllerProvider(_sourceSessionTag));

    // Mirror the live transcript into the text field while listening, same
    // pattern as the Voice tab's field.
    if (sourceRecognition.isListening && _sourceTextController.text != sourceRecognition.transcript) {
      _sourceTextController.value = _sourceTextController.value.copyWith(
        text: sourceRecognition.transcript,
        selection: TextSelection.collapsed(offset: sourceRecognition.transcript.length),
      );
    }

    ref.listen(speechControllerProvider(_sourceSessionTag), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add entry', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('EEEE, MMM d, yyyy · h:mm a').format(_date)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LanguageSelectorChip(
                    language: _sourceLanguage,
                    onTap: _pickLanguage,
                  ),
                  FolderSelectorChip(folderName: folderName, onTap: _pickFolder),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceTextController,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: sourceRecognition.isListening ? 'Listening…' : 'Type or speak the text',
                  suffixIcon: IconButton(
                    icon: Icon(sourceRecognition.isListening ? Icons.stop_circle_rounded : Icons.mic_rounded),
                    tooltip: sourceRecognition.isListening ? 'Stop' : 'Dictate',
                    onPressed: () => _toggleListening(sourceRecognition.isListening),
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter some text' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                subtitle: Text(
                  _reminderEnabled && _reminderAt != null
                      ? DateFormat('EEEE, MMM d, yyyy · h:mm a').format(_reminderAt!)
                      : 'Get a notification at a chosen time',
                ),
                value: _reminderEnabled,
                onChanged: _onReminderToggled,
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _pickReminderTime,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    _reminderAt == null
                        ? 'Set reminder time'
                        : DateFormat('MMM d, h:mm a').format(_reminderAt!),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Add entry')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleListening(bool isListening) async {
    final controller = ref.read(speechControllerProvider(_sourceSessionTag).notifier);
    if (isListening) {
      await controller.stopListening();
    } else {
      await controller.startListening(_sourceLanguage.localeHint);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;

    setState(() {
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _date.hour,
        pickedTime?.minute ?? _date.minute,
      );
    });
  }

  Future<void> _pickLanguage() async {
    final picked = await context.push<Language>(
      '/language-picker',
      extra: {'title': 'Speech language', 'selectedCode': _sourceLanguage.code},
    );
    if (picked != null) {
      setState(() => _sourceLanguage = picked);
    }
  }

  Future<void> _onReminderToggled(bool value) async {
    if (!value) {
      setState(() {
        _reminderEnabled = false;
        _reminderAt = null;
      });
      return;
    }
    final granted = await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    if (!granted) {
      AppSnackbar.show(context, 'Allow notifications to get reminders', isError: true);
      return;
    }
    setState(() {
      _reminderEnabled = true;
      _reminderAt ??= _date.isAfter(DateTime.now()) ? _date : DateTime.now().add(const Duration(hours: 1));
    });
  }

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final initial = _reminderAt ?? (_date.isAfter(now) ? _date : now.add(const Duration(hours: 1)));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;

    setState(() {
      _reminderAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? initial.hour,
        pickedTime?.minute ?? initial.minute,
      );
    });
  }

  Future<void> _pickFolder() async {
    final result = await showFolderPicker(context, selectedFolderId: _folderId);
    if (result == null) return;
    setState(() => _folderId = result.isEmpty ? null : result);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_reminderEnabled && _reminderAt != null && !_reminderAt!.isAfter(DateTime.now())) {
      AppSnackbar.show(context, 'Reminder time must be in the future', isError: true);
      return;
    }
    final reminderAt = _reminderEnabled ? _reminderAt : null;

    final item = HistoryItem.voice(
      text: _sourceTextController.text.trim(),
      languageCode: _sourceLanguage.code,
      folderId: _folderId,
      timestamp: _date,
      reminderAt: reminderAt,
    );

    await ref.read(historyControllerProvider.notifier).addEntry(item);
    if (mounted) {
      Navigator.pop(context);
      AppSnackbar.show(context, 'Entry added to ${DateFormat('MMM d').format(_date)}');
    }
  }
}
