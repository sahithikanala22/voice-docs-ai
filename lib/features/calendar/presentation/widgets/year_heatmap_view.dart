import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// GitHub-contribution-graph-style overview of a whole year — one row per
/// month, one small square per day, shaded by how many entries were saved
/// that day. Lets you spot journaling consistency (or gaps) at a glance in
/// a way a single month grid can't.
class YearHeatmapView extends StatelessWidget {
  const YearHeatmapView({super.key, required this.year, required this.countsForDay, required this.onDaySelected});

  final int year;
  final int Function(DateTime day) countsForDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: 12,
      itemBuilder: (context, monthIndex) {
        final month = monthIndex + 1;
        final daysInMonth = DateUtils.getDaysInMonth(year, month);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  DateFormat('MMM').format(DateTime(year, month)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (var d = 1; d <= daysInMonth; d++)
                      Builder(builder: (context) {
                        final day = DateTime(year, month, d);
                        final isFuture = day.isAfter(today);
                        final count = isFuture ? 0 : countsForDay(day);
                        return GestureDetector(
                          onTap: isFuture ? null : () => onDaySelected(day),
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2.5),
                              color: isFuture
                                  ? scheme.surfaceContainerHighest
                                  : count == 0
                                      ? scheme.surfaceContainerHigh
                                      : scheme.primary
                                          .withValues(alpha: (0.28 + (count.clamp(0, 4) * 0.18)).clamp(0.28, 1.0)),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
