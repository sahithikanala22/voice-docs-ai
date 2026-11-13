import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_detail_sheet.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/widgets/recording_audio_card.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/recording_playback_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';
import '../../domain/library_entry.dart';

class LibraryEntryTile extends ConsumerWidget {
  const LibraryEntryTile({super.key, required this.entry});
  final LibraryEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (entry.kind) {
      LibraryKind.voice => Icons.graphic_eq_rounded,
      LibraryKind.journal => Icons.auto_stories_outlined,
      LibraryKind.task =>
        entry.task!.isDoneNow
            ? Icons.check_circle_outline
            : Icons.checklist_rounded,
      LibraryKind.audio => Icons.headphones_rounded,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${entry.kind.label} · ${DateFormat(entry.kind == LibraryKind.journal ? 'd MMM yyyy' : 'd MMM · h:mm a').format(entry.date)}',
          maxLines: 2,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => openLibraryEntry(context, ref, entry),
      ),
    );
  }
}

void openLibraryEntry(BuildContext context, WidgetRef ref, LibraryEntry entry) {
  switch (entry.kind) {
    case LibraryKind.voice:
      showHistoryDetailSheet(context, ref, entry.voice!);
    case LibraryKind.journal:
      context.push('/diary-entry/${entry.journal!.id}');
    case LibraryKind.task:
      final task = entry.task!;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(task.isDoneNow ? 'Completed' : 'Open task'),
                if (task.reminderAt != null)
                  Text(
                    'Reminder · ${DateFormat.yMMMd().add_jm().format(task.reminderAt!)}',
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: Icon(
                    task.isDoneNow ? Icons.undo_rounded : Icons.check_rounded,
                  ),
                  label: Text(
                    task.isDoneNow ? 'Mark incomplete' : 'Complete task',
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(taskControllerProvider.notifier)
                          .setDone(task.id, !task.isDoneNow);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {
                      if (sheetContext.mounted) {
                        AppSnackbar.show(
                          sheetContext,
                          'Could not update this task. Try again.',
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    case LibraryKind.audio:
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                RecordingAudioCard(recordingId: entry.audio!.id),
                if (entry.text.isNotEmpty) SelectableText(entry.text),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Transcribe or manage recording'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/recover-recordings');
                  },
                ),
              ],
            ),
          ),
        ),
      ).whenComplete(() {
        if (context.mounted && ref.exists(recordingPlaybackProvider)) {
          ref.read(recordingPlaybackProvider).stop();
        }
      });
  }
}
