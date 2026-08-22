import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/history_item.dart';
import '../providers/history_providers.dart';

/// Consecutive-day journaling streak, counting back from today (or from
/// yesterday if nothing's been saved yet today, so the streak doesn't drop
/// to zero the moment midnight passes before you've had a chance to write).
int _computeStreak(List<HistoryItem> items) {
  final days = items.map((e) => DateUtils.dateOnly(e.timestamp)).toSet();
  var day = DateUtils.dateOnly(DateTime.now());
  if (!days.contains(day)) {
    day = day.subtract(const Duration(days: 1));
    if (!days.contains(day)) return 0;
  }
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// A slim "N day streak" pill (with a flame icon) on the Voice tab — only shows once there's
/// an actual streak worth celebrating (2+ days), so a brand-new user never
/// sees a deflating "0 day streak".
class StreakBadge extends ConsumerWidget {
  const StreakBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyControllerProvider).value ?? const [];
    final streak = _computeStreak(items);
    if (streak < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: scheme.onTertiaryContainer),
              const SizedBox(width: 4),
              Text(
                '$streak day streak',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
