import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/widgets/brand_widgets.dart';
import 'package:ai_voice_docs/features/library/domain/library_entry.dart';
import 'package:ai_voice_docs/features/library/presentation/providers/library_providers.dart';
import 'package:ai_voice_docs/features/library/presentation/widgets/library_entry_tile.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(savedRecordingsProvider);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final library = ref.watch(libraryProvider);
    final tasks = ref.watch(taskControllerProvider);
    final open = (tasks.value ?? <Task>[])
        .where((task) => !task.isDoneNow)
        .toList();
    final upcoming = open.where((task) {
      final reminder = task.reminderAt;
      if (reminder == null) return false;
      if (task.recurrence == TaskRecurrence.daily) {
        return !DateUtils.dateOnly(reminder).isAfter(DateUtils.dateOnly(now));
      }
      if (task.recurrence == TaskRecurrence.weekly) {
        return reminder.weekday == now.weekday &&
            !reminder.isAfter(
              DateTime(now.year, now.month, now.day, 23, 59, 59),
            );
      }
      return reminder.isBefore(DateTime(now.year, now.month, now.day + 1));
    }).toList()..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    final recent = library.entries
        .where((e) => e.kind != LibraryKind.task)
        .take(3)
        .toList();
    final greeting = now.hour < 12
        ? 'Good morning.'
        : now.hour < 17
        ? 'Good afternoon.'
        : 'Good evening.';
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppTitle(),
        actions: [
          IconButton(
            onPressed: () => context.go('/library'),
            tooltip: 'Search everything',
            icon: const Icon(Icons.search_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(now),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(greeting, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              'A little space for your thoughts.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.primaryContainer,
              child: InkWell(
                key: const ValueKey('today-record'),
                onTap: () => context.push('/record'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 32,
                            color: scheme.onPrimaryContainer,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_outward_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Record a note',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A thought, an idea, a moment worth keeping.',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/diary-entry/new'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Write entry'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/calendar'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Calendar'),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/meeting-recorder'),
                  icon: const Icon(Icons.headphones_outlined),
                  label: const Text('Record audio'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: upcoming.isEmpty ? 'Next up' : 'Due today & overdue',
              action: 'All tasks',
              onTap: () => context.go('/tasks'),
            ),
            if (tasks.isLoading) const LinearProgressIndicator(),
            if (tasks.hasError)
              const Text('Tasks could not be loaded. Open Tasks to retry.'),
            if (!tasks.isLoading && !tasks.hasError && open.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: const Text('Room to breathe.'),
                  subtitle: const Text(
                    'No open tasks. Capture one whenever you need.',
                  ),
                  onTap: () => context.go('/tasks'),
                ),
              ),
            for (final task in (upcoming.isEmpty ? open : upcoming).take(3))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.radio_button_unchecked_rounded),
                  title: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: task.reminderAt == null
                      ? null
                      : Text(
                          task.recurrence == TaskRecurrence.none
                              ? DateFormat(
                                  'd MMM · h:mm a',
                                ).format(task.reminderAt!)
                              : '${task.recurrence.name} · ${DateFormat.jm().format(task.reminderAt!)}',
                        ),
                  onTap: () => openLibraryEntry(
                    context,
                    ref,
                    LibraryEntry(
                      id: 'task:${task.id}',
                      kind: LibraryKind.task,
                      title: task.title,
                      text: task.title,
                      date: task.createdAt,
                      task: task,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Recently saved',
              action: 'Open Library',
              onTap: () => context.go('/library'),
            ),
            if (library.loading) const LinearProgressIndicator(),
            if (library.hasError)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Some saved items could not be loaded. Open Library to retry.',
                ),
              ),
            if (recent.isEmpty && !library.loading && !library.hasError)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.bookmarks_outlined),
                      const SizedBox(height: 12),
                      Text(
                        'Start with one thought.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your notes and journal entries will appear here.',
                      ),
                    ],
                  ),
                ),
              ),
            for (final entry in recent) LibraryEntryTile(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}
