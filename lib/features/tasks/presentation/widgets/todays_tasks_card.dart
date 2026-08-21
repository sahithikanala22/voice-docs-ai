import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../providers/task_providers.dart';

/// A simple checklist card on the Voice/Home tab — add a task, check it off,
/// it stays until you clear it. Deliberately date-less (see [Task]'s doc
/// comment): this is a running "today" list, not tied to the Calendar.
class TodaysTasksCard extends ConsumerWidget {
  const TodaysTasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final pending = tasks.where((t) => !t.isDone).toList();
    final completed = tasks.where((t) => t.isDone).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Today's tasks", style: Theme.of(context).textTheme.labelLarge),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'Add task',
                onPressed: () => _addTask(context, ref),
              ),
            ],
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              child: Text(
                'Nothing yet — tap + to add a task.',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final task in pending) _TaskRow(task: task),
          if (completed.isNotEmpty) ...[
            for (final task in completed) _TaskRow(task: task),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref.read(taskControllerProvider.notifier).clearCompleted(),
                child: const Text('Clear completed'),
              ),
            ),
          ] else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What do you need to do?'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await ref.read(taskControllerProvider.notifier).addTask(trimmed);
    }
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Checkbox(
          value: task.isDone,
          onChanged: (value) =>
              ref.read(taskControllerProvider.notifier).setDone(task.id, value ?? false),
        ),
        Expanded(
          child: Text(
            task.title,
            style: TextStyle(
              decoration: task.isDone ? TextDecoration.lineThrough : null,
              color: task.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: 'Remove task',
          onPressed: () => ref.read(taskControllerProvider.notifier).removeTask(task.id),
        ),
      ],
    );
  }
}
