import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

const _weekdayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

/// A fixed 6-week month grid (so switching months never changes the grid's
/// height) with per-day dots showing which folders have entries that day.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
    required this.dotsForDay,
  });

  /// Any date within the month to display — only year/month are used.
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Folder colors (deduplicated) for entries on [day] — empty if none.
  final List<Color> Function(DateTime day) dotsForDay;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    // firstOfMonth.weekday is 1 (Mon) .. 7 (Sun); shift so the grid starts on
    // the Sunday on/before the 1st, matching the Su-Sa header.
    final leadingDays = firstOfMonth.weekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingDays));
    final today = DateUtils.dateOnly(DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++) ...[
                Builder(builder: (context) {
                  final day = gridStart.add(Duration(days: week * 7 + weekday));
                  final inMonth = day.month == month.month;
                  final isToday = DateUtils.isSameDay(day, today);
                  final isSelected = DateUtils.isSameDay(day, selectedDay);
                  final dots = dotsForDay(day);

                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () => onDaySelected(day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected ? AppTheme.heroGradient(scheme) : null,
                            border: !isSelected && isToday
                                ? Border.all(color: scheme.primary, width: 1.6)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: scheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : !inMonth
                                          ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                                          : isToday
                                              ? scheme.primary
                                              : scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 5,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final color in dots.take(3))
                                      Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? Colors.white : color,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
      ],
    );
  }
}
