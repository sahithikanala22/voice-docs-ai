import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/diary_providers.dart';

/// Surfaces diary entries written on this same month/day in a previous
/// year — the diary counterpart to History's `OnThisDayCard`. Hidden
/// entirely when there's nothing to show.
class DiaryOnThisDayCard extends ConsumerWidget {
  const DiaryOnThisDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(diaryControllerProvider).value ?? const [];
    final today = DateTime.now();
    final memories = entries
        .where((e) => e.date.month == today.month && e.date.day == today.day && e.date.year != today.year)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (memories.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text('On this day', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          for (final entry in memories.take(3))
            InkWell(
              onTap: () => context.push('/diary-entry/${entry.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${today.year - entry.date.year}y ago',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.title.trim().isNotEmpty ? entry.title.trim() : entry.body.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
