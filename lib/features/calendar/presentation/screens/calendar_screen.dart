import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_filter_chip.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_detail_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_tile.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/share_format_sheet.dart';

import '../widgets/add_entry_sheet.dart';
import '../widgets/month_calendar_grid.dart';
import '../widgets/year_heatmap_view.dart';

/// Browse saved entries by date: a month grid with per-day folder dots, tap
/// a day to see everything saved on it. Reuses the exact same detail sheet,
/// tile, and folder filter as History so both views stay in sync.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _visibleMonth = DateUtils.dateOnly(DateTime.now());
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());

  /// `null` = All, `''` = Unfiled, otherwise a folder id — same convention
  /// as the History screen's filter.
  String? _filterFolderId;

  bool _showYear = false;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);
    final foldersAsync = ref.watch(folderControllerProvider);
    final folders = foldersAsync.value ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showYear ? Icons.calendar_view_month_rounded : Icons.grid_view_rounded),
            tooltip: _showYear ? 'Month view' : 'Year view',
            onPressed: () => setState(() => _showYear = !_showYear),
          ),
        ],
        bottom: const GradientAppBarUnderline(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEntrySheet(context, initialDate: _selectedDay),
        tooltip: 'Add entry for this day',
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Could not load history: $err')),
          data: (items) {
            final filteredItems = _filterFolderId == null
                ? items
                : items
                    .where((e) => _filterFolderId == '' ? e.folderId == null : e.folderId == _filterFolderId)
                    .toList();

            final entriesByDay = <DateTime, List<HistoryItem>>{};
            for (final item in filteredItems) {
              entriesByDay.putIfAbsent(DateUtils.dateOnly(item.timestamp), () => []).add(item);
            }

            final monthItems = filteredItems
                .where((e) => e.timestamp.year == _visibleMonth.year && e.timestamp.month == _visibleMonth.month)
                .toList();
            final monthEntryCount = monthItems.length;
            final yearEntryCount =
                filteredItems.where((e) => e.timestamp.year == _visibleMonth.year).length;
            final selectedDayEntries = entriesByDay[_selectedDay] ?? const <HistoryItem>[];
            final today = DateUtils.dateOnly(DateTime.now());
            final isToday = DateUtils.isSameDay(_selectedDay, today);
            final isCurrentMonth = _visibleMonth.year == today.year && _visibleMonth.month == today.month;
            final isCurrentYear = _visibleMonth.year == today.year;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.16),
                          scheme.tertiary.withValues(alpha: 0.16),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MonthNavButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: _showYear ? 'Previous year' : 'Previous month',
                          onTap: () => setState(() {
                            _visibleMonth = _showYear
                                ? DateTime(_visibleMonth.year - 1, _visibleMonth.month)
                                : DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                          }),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _showYear
                                    ? '${_visibleMonth.year}'
                                    : DateFormat('MMMM yyyy').format(_visibleMonth),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: scheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _showYear
                                    ? '$yearEntryCount ${yearEntryCount == 1 ? 'entry' : 'entries'} this year'
                                    : '$monthEntryCount ${monthEntryCount == 1 ? 'entry' : 'entries'} this month',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                              ),
                              if (_showYear ? !isCurrentYear : (!isCurrentMonth || !isToday)) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _visibleMonth = today;
                                    _selectedDay = today;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: scheme.surface.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'Jump to today',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _MonthNavButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: _showYear ? 'Next year' : 'Next month',
                          onTap: () => setState(() {
                            _visibleMonth = _showYear
                                ? DateTime(_visibleMonth.year + 1, _visibleMonth.month)
                                : DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showYear)
                  Expanded(
                    child: YearHeatmapView(
                      year: _visibleMonth.year,
                      countsForDay: (day) => entriesByDay[day]?.length ?? 0,
                      onDaySelected: (day) => setState(() {
                        _showYear = false;
                        _selectedDay = day;
                        _visibleMonth = DateTime(day.year, day.month);
                      }),
                    ),
                  )
                else ...[
                if (monthItems.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: TextButton.icon(
                        onPressed: () => showDigestShareFormatSheet(
                          context,
                          monthItems,
                          title: DateFormat('MMMM yyyy').format(_visibleMonth),
                          fileSlug: DateFormat('yyyy_MM').format(_visibleMonth),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 16),
                        label: const Text('Export month'),
                      ),
                    ),
                  ),
                if (folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          FolderFilterChip(
                            label: 'All',
                            selected: _filterFolderId == null,
                            onSelected: () => setState(() => _filterFolderId = null),
                          ),
                          const SizedBox(width: 8),
                          FolderFilterChip(
                            label: 'Unfiled',
                            selected: _filterFolderId == '',
                            onSelected: () => setState(() => _filterFolderId = ''),
                          ),
                          for (final folder in folders) ...[
                            const SizedBox(width: 8),
                            FolderFilterChip(
                              label: folder.name,
                              color: folderColorFor(folders, folder.id),
                              selected: _filterFolderId == folder.id,
                              onSelected: () => setState(() => _filterFolderId = folder.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: MonthCalendarGrid(
                        month: _visibleMonth,
                        selectedDay: _selectedDay,
                        onDaySelected: (day) => setState(() {
                          _selectedDay = day;
                          if (day.month != _visibleMonth.month || day.year != _visibleMonth.year) {
                            _visibleMonth = DateTime(day.year, day.month);
                          }
                        }),
                        dotsForDay: (day) {
                          final dayItems = entriesByDay[day];
                          if (dayItems == null || dayItems.isEmpty) return const [];
                          return {for (final item in dayItems) folderColorFor(folders, item.folderId)}
                              .toList();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        isToday ? Icons.today_rounded : Icons.event_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isToday ? 'Today' : DateFormat('EEEE, MMM d').format(_selectedDay),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (selectedDayEntries.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${selectedDayEntries.length}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: selectedDayEntries.isEmpty
                      ? Column(
                          children: [
                            const Expanded(
                              child: EmptyState(
                                icon: Icons.event_note_outlined,
                                title: 'No entries this day',
                                subtitle:
                                    'Voice transcripts saved on this day will show up here.',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextButton.icon(
                                onPressed: () => showAddEntrySheet(context, initialDate: _selectedDay),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add entry for this day'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: selectedDayEntries.length,
                          itemBuilder: (context, index) {
                            final item = selectedDayEntries[index];
                            return HistoryTile(
                              item: item,
                              folder: folderByIdOrNull(folders, item.folderId),
                              onTap: () => showHistoryDetailSheet(context, ref, item),
                              onDelete: () {
                                ref.read(historyControllerProvider.notifier).removeEntry(item.id);
                                AppSnackbar.show(context, 'Removed from history');
                              },
                              onShare: () => showShareFormatSheet(context, item),
                            );
                          },
                        ),
                ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Small circular chevron button for stepping the visible month, styled to
/// sit on top of the gradient header card rather than the plain surface
/// `IconButton` default.
class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      child: IconButton(icon: Icon(icon), tooltip: tooltip, color: scheme.primary, onPressed: onTap),
    );
  }
}
