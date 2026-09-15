import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/floating_dots_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/calendar/presentation/widgets/add_entry_sheet.dart';
import 'package:ai_voice_docs/features/folders/data/folder.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_detail_sheet.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/history_tile.dart';
import 'package:ai_voice_docs/features/history/presentation/widgets/share_format_sheet.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

/// One day's worth of diary content: voice entries recorded that day, tasks
/// added that day, and reminders (from either source) landing on that day —
/// a reminder is only surfaced here when it falls on a *different* day than
/// the item's own creation, since a same-day reminder would otherwise just
/// duplicate the entry/task row directly below it.
class _DiaryDay {
  _DiaryDay(this.date);

  final DateTime date;
  final List<HistoryItem> entries = [];
  final List<Task> tasksCreated = [];
  final List<_DiaryReminder> reminders = [];
}

class _DiaryReminder {
  const _DiaryReminder({
    required this.time,
    required this.label,
    required this.isTask,
    this.historyItem,
  });

  final DateTime time;
  final String label;
  final bool isTask;
  final HistoryItem? historyItem;
}

/// A single day-by-day journal combining Voice history, Tasks, and reminders
/// into one read-through feed — everything that happened on a given day in
/// one place, rather than split across three separate tabs. A search field
/// filters the feed by text, and the FAB adds a new entry for today via the
/// same sheet the Calendar tab uses.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);
    final tasksAsync = ref.watch(taskControllerProvider);
    final foldersAsync = ref.watch(folderControllerProvider);
    final folders = foldersAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        bottom: const GradientAppBarUnderline(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEntrySheet(context, initialDate: DateTime.now()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
      body: FloatingDotsBackground(
        child: SafeArea(
          child: historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Center(child: Text('Could not load diary: $err')),
            data: (historyItems) {
              final tasks = tasksAsync.value ?? const [];
              if (historyItems.isEmpty && tasks.isEmpty) {
                return const EmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'Your diary is empty',
                  subtitle:
                      'Everything you record, save, or complete shows up here, organized day by day.',
                );
              }

              final filteredHistory = _query.isEmpty
                  ? historyItems
                  : historyItems
                        .where((e) => e.sourceText.toLowerCase().contains(_query))
                        .toList();
              final filteredTasks = _query.isEmpty
                  ? tasks
                  : tasks.where((t) => t.title.toLowerCase().contains(_query)).toList();

              final days = _buildDiaryDays(filteredHistory, filteredTasks);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search diary',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: days.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              subtitle: 'Nothing in your diary matches that search.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: days.length,
                              itemBuilder: (context, index) => _DiaryDaySection(
                                day: days[index],
                                folders: folders,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<_DiaryDay> _buildDiaryDays(List<HistoryItem> historyItems, List<Task> tasks) {
    final byDate = <DateTime, _DiaryDay>{};
    _DiaryDay dayFor(DateTime date) =>
        byDate.putIfAbsent(date, () => _DiaryDay(date));

    for (final item in historyItems) {
      final entryDay = DateUtils.dateOnly(item.timestamp);
      dayFor(entryDay).entries.add(item);

      final reminderAt = item.reminderAt;
      if (reminderAt != null) {
        final reminderDay = DateUtils.dateOnly(reminderAt);
        if (reminderDay != entryDay) {
          dayFor(reminderDay).reminders.add(
            _DiaryReminder(
              time: reminderAt,
              label: item.sourceText,
              isTask: false,
              historyItem: item,
            ),
          );
        }
      }
    }

    for (final task in tasks) {
      final createdDay = DateUtils.dateOnly(task.createdAt);
      dayFor(createdDay).tasksCreated.add(task);

      final reminderAt = task.reminderAt;
      if (reminderAt != null && task.recurrence == TaskRecurrence.none) {
        final reminderDay = DateUtils.dateOnly(reminderAt);
        if (reminderDay != createdDay) {
          dayFor(reminderDay).reminders.add(
            _DiaryReminder(time: reminderAt, label: task.title, isTask: true),
          );
        }
      }
    }

    for (final day in byDate.values) {
      day.entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      day.reminders.sort((a, b) => a.time.compareTo(b.time));
    }

    return byDate.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _DiaryDaySection extends ConsumerWidget {
  const _DiaryDaySection({required this.day, required this.folders});

  final _DiaryDay day;
  final List<Folder> folders;

  String get _dateLabel {
    final today = DateUtils.dateOnly(DateTime.now());
    if (day.date == today) return 'Today';
    if (day.date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat(
      day.date.year == today.year ? 'EEEE, MMM d' : 'EEEE, MMM d, yyyy',
    ).format(day.date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = day.entries.length + day.tasksCreated.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_dateLabel, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (itemCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$itemCount',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (day.reminders.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DiaryRemindersCard(reminders: day.reminders, ref: ref),
          ],
          if (day.entries.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final item in day.entries)
              HistoryTile(
                item: item,
                folder: folderByIdOrNull(folders, item.folderId),
                onTap: () => showHistoryDetailSheet(context, ref, item),
                onDelete: () {
                  ref.read(historyControllerProvider.notifier).removeEntry(item.id);
                  AppSnackbar.show(context, 'Removed from history');
                },
                onShare: () => showShareFormatSheet(context, item),
              ),
          ],
          if (day.tasksCreated.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final task in day.tasksCreated) _DiaryTaskRow(task: task),
          ],
        ],
      ),
    );
  }
}

/// Compact list of reminders landing on this day, drawn from both voice
/// entries and tasks — tapping a voice reminder opens its detail sheet;
/// tapping a task reminder jumps to the Tasks tab, where it can be edited.
class _DiaryRemindersCard extends StatelessWidget {
  const _DiaryRemindersCard({required this.reminders, required this.ref});

  final List<_DiaryReminder> reminders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.tertiary.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reminder in reminders)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (reminder.isTask) {
                  context.go('/tasks');
                } else if (reminder.historyItem != null) {
                  showHistoryDetailSheet(context, ref, reminder.historyItem!);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      reminder.isTask
                          ? Icons.checklist_rounded
                          : Icons.notifications_active_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('h:mm a').format(reminder.time),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reminder.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
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

/// Read-mostly summary of a task added on this day — a live checkbox so a
/// diary read-through can still mark something done, but reminder/recurrence
/// editing stays on the Tasks tab rather than being duplicated here.
class _DiaryTaskRow extends ConsumerWidget {
  const _DiaryTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.isDoneNow;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => context.go('/tasks'),
        leading: Checkbox(
          value: done,
          onChanged: (value) =>
              ref.read(taskControllerProvider.notifier).setDone(task.id, value ?? false),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
        trailing: task.recurrence != TaskRecurrence.none
            ? Icon(
                task.recurrence == TaskRecurrence.daily
                    ? Icons.repeat_rounded
                    : Icons.event_repeat_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}
