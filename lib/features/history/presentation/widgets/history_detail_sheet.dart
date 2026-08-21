import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../../data/history_item.dart';
import '../../data/history_pdf_generator.dart';
import '../../data/history_word_generator.dart';
import '../providers/history_providers.dart';
import 'share_format_sheet.dart';

/// The full-detail bottom sheet for one history entry — date/folder, the
/// transcript text, and the move/reminder/share/play actions. Shared by
/// every screen that lets you tap into an entry (History, Calendar, ...) so
/// they all get the exact same detail view instead of drifting apart.
void showHistoryDetailSheet(BuildContext context, WidgetRef ref, HistoryItem item) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: 14,
                      color: item.folderId == null
                          ? Theme.of(sheetContext).colorScheme.onSurfaceVariant
                          : folderColorFor(ref.read(folderControllerProvider).value, item.folderId),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      folderNameFor(ref.read(folderControllerProvider).value, item.folderId),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.reminderAt != null) ...[
              Row(
                children: [
                  Icon(Icons.notifications_active_rounded, size: 16, color: Theme.of(sheetContext).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reminder: ${DateFormat('MMM d, yyyy · h:mm a').format(item.reminderAt!)}',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(sheetContext).colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Remove reminder',
                    onPressed: () => _clearReminder(context, ref, item),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(languageByCode(item.sourceLanguageCode).name,
                style: Theme.of(sheetContext).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(item.sourceText, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _moveToFolder(context, ref, item),
                  icon: const Icon(Icons.drive_file_move_outlined),
                  label: const Text('Move to folder'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _setReminder(context, ref, item),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(item.reminderAt == null ? 'Set reminder' : 'Change reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: () => shareGeneratedFile(
                    context,
                    () => HistoryPdfGenerator().generate(item),
                    'Could not create the PDF.',
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => shareGeneratedFile(
                    context,
                    () => HistoryWordGenerator().generate(item),
                    'Could not create the Word document.',
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Share Word'),
                ),
                FilledButton.icon(
                  onPressed: () => ref.read(ttsControllerProvider.notifier).speak(
                        item.sourceText,
                        languageByCode(item.sourceLanguageCode).localeHint,
                      ),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Play'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _setReminder(BuildContext context, WidgetRef ref, HistoryItem item) async {
  final now = DateTime.now();
  final initial = item.reminderAt != null && item.reminderAt!.isAfter(now)
      ? item.reminderAt!
      : now.add(const Duration(hours: 1));

  final granted = await ref.read(notificationServiceProvider).requestPermission();
  if (!context.mounted) return;
  if (!granted) {
    AppSnackbar.show(context, 'Allow notifications to get reminders', isError: true);
    return;
  }

  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: now,
    lastDate: DateTime(now.year + 10),
  );
  if (pickedDate == null || !context.mounted) return;

  final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (!context.mounted) return;

  final reminderAt = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime?.hour ?? initial.hour,
    pickedTime?.minute ?? initial.minute,
  );
  if (!reminderAt.isAfter(DateTime.now())) {
    AppSnackbar.show(context, 'Reminder time must be in the future', isError: true);
    return;
  }

  await ref.read(historyControllerProvider.notifier).setReminder(item.id, reminderAt);
  if (context.mounted) {
    Navigator.pop(context);
    AppSnackbar.show(context, 'Reminder set for ${DateFormat('MMM d, h:mm a').format(reminderAt)}');
  }
}

Future<void> _clearReminder(BuildContext context, WidgetRef ref, HistoryItem item) async {
  await ref.read(historyControllerProvider.notifier).setReminder(item.id, null);
  if (context.mounted) {
    Navigator.pop(context);
    AppSnackbar.show(context, 'Reminder removed');
  }
}

Future<void> _moveToFolder(BuildContext context, WidgetRef ref, HistoryItem item) async {
  final result = await showFolderPicker(context, selectedFolderId: item.folderId);
  if (result == null) return;
  final newFolderId = result.isEmpty ? null : result;
  await ref.read(historyControllerProvider.notifier).moveToFolder(item.id, newFolderId);
  if (context.mounted) {
    Navigator.pop(context);
    AppSnackbar.show(
      context,
      'Moved to ${folderNameFor(ref.read(folderControllerProvider).value, newFolderId)}',
    );
  }
}
