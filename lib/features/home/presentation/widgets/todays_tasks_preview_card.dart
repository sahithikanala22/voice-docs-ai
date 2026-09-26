import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

/// A light preview of pending tasks — enough to glance at and check a couple
/// off without leaving Home, with "See all" for the full Tasks tab.
class TodaysTasksPreviewCard extends ConsumerWidget {
  const TodaysTasksPreviewCard({super.key});

  static const _previewLimit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(taskControllerProvider).value ?? const [];
    final pending = tasks.where((t) => !t.isDoneNow).toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    final preview = pending.take(_previewLimit).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Today's tasks",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              TextButton(onPressed: () => context.go('/tasks'), child: const Text('See all')),
            ],
          ),
          for (final task in preview)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref.read(taskControllerProvider.notifier).setDone(task.id, true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked_rounded, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
