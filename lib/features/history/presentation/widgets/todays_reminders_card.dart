import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/history_providers.dart';
import 'history_detail_sheet.dart';

/// A compact card listing every entry with a reminder scheduled for today,
/// earliest first — shown at the top of the Voice/Home tab so reminders are
/// the first thing you see on opening the app, not something you have to go
/// dig for in History. Renders nothing when there are none, so it never eats
/// space on a normal day.
class TodaysRemindersCard extends ConsumerWidget {
  const TodaysRemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyControllerProvider).value ?? const [];
    final today = DateUtils.dateOnly(DateTime.now());
    final todaysReminders = items.where((e) {
      final reminderAt = e.reminderAt;
      return reminderAt != null && DateUtils.isSameDay(reminderAt, today);
    }).toList()
      ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));

    if (todaysReminders.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.16), scheme.tertiary.withValues(alpha: 0.16)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                "Today's reminders",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in todaysReminders)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showHistoryDetailSheet(context, ref, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.reminderAt!.isBefore(now) ? scheme.onSurfaceVariant : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('h:mm a').format(item.reminderAt!),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.sourceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
