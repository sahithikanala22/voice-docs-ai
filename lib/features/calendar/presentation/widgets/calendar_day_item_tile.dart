import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

/// A task shown on Calendar's day list — same `Card`+`ListTile` shape as
/// `HistoryTile` so a mixed day (voice + task + diary) reads as one
/// consistent list rather than three different-looking widgets.
class TaskDayTile extends ConsumerWidget {
  const TaskDayTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.isDoneNow;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => ref.read(taskControllerProvider.notifier).setDone(task.id, !done),
        leading: Checkbox(
          value: done,
          onChanged: (value) => ref.read(taskControllerProvider.notifier).setDone(task.id, value ?? false),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        subtitle: task.reminderAt != null ? Text(DateFormat('h:mm a').format(task.reminderAt!)) : null,
        trailing: task.recurrence != TaskRecurrence.none
            ? Icon(
                task.recurrence == TaskRecurrence.daily ? Icons.repeat_rounded : Icons.event_repeat_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

/// A diary entry shown on Calendar's day list — same shape as [TaskDayTile]
/// and `HistoryTile`. Tapping opens the entry's own read view.
class DiaryDayTile extends StatelessWidget {
  const DiaryDayTile({super.key, required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isNotEmpty ? entry.title.trim() : entry.body.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/diary-entry/${entry.id}'),
        leading: entry.mood != null
            ? Text(entry.mood!.emoji, style: const TextStyle(fontSize: 22))
            : const Icon(Icons.auto_stories_outlined),
        title: Text(
          title.isEmpty ? 'Diary entry' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text('Diary entry'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
