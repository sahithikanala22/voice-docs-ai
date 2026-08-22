import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_providers.dart';
import 'history_detail_sheet.dart';

/// Surfaces entries saved on this same month/day in a previous year —
/// a lightweight "memories" touch, diary-app style. Hidden entirely when
/// there's nothing to show, same as the reminders/tasks cards above it.
class OnThisDayCard extends ConsumerWidget {
  const OnThisDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyControllerProvider).value ?? const [];
    final today = DateTime.now();
    final memories = items
        .where((e) =>
            e.timestamp.month == today.month &&
            e.timestamp.day == today.day &&
            e.timestamp.year != today.year)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (memories.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
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
              Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text('On this day', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          for (final item in memories.take(3))
            InkWell(
              onTap: () => showHistoryDetailSheet(context, ref, item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${today.year - item.timestamp.year}y ago',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.sourceText, maxLines: 1, overflow: TextOverflow.ellipsis),
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
