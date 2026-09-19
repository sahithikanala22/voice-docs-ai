import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';

import '../../data/diary_entry.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_entry_card.dart';

/// The diary: a personal journal of composed entries — photos, a mood and a
/// themed page each. Unlike History (quick voice captures), nothing lands here
/// unless you write it here.
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
    final entriesAsync = ref.watch(diaryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        bottom: const GradientAppBarUnderline(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diary-entry/new'),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New entry'),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Could not load your diary: $err')),
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'Start your diary',
                  subtitle: 'Write about your day, add photos, pick a mood and a page theme.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/diary-entry/new'),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Write your first entry'),
                  ),
                );
              }

              final visible = _query.isEmpty
                  ? entries
                  : entries
                        .where(
                          (e) =>
                              e.title.toLowerCase().contains(_query) ||
                              e.body.toLowerCase().contains(_query),
                        )
                        .toList();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _DiaryStats(entries: entries),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search your diary',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              subtitle: 'No diary entry mentions that.',
                            )
                          : _GroupedEntryList(entries: visible),
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
}

/// Entries grouped under a month heading, newest first.
class _GroupedEntryList extends StatelessWidget {
  const _GroupedEntryList({required this.entries});

  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Entries arrive sorted newest first, so a month heading goes in wherever
    // the month changes from the previous entry.
    final rows = <Object>[];
    DateTime? currentMonth;
    for (final entry in entries) {
      final month = DateTime(entry.date.year, entry.date.month);
      if (month != currentMonth) {
        rows.add(month);
        currentMonth = month;
      }
      rows.add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is DateTime) return _MonthHeading(month: row);
        final entry = row as DiaryEntry;
        return DiaryEntryCard(
          key: ValueKey(entry.id),
          entry: entry,
          onTap: () => context.push('/diary-entry/${entry.id}'),
        );
      },
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        DateFormat('MMMM yyyy').format(month).toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Entry count, writing streak and photo count — a small nudge to keep going.
class _DiaryStats extends StatelessWidget {
  const _DiaryStats({required this.entries});

  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final streak = diaryStreak(entries, DateTime.now());
    final photos = entries.fold<int>(0, (sum, e) => sum + e.photos.length);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.tertiary.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _Stat(value: '${entries.length}', label: entries.length == 1 ? 'entry' : 'entries'),
          _Stat(value: '🔥 $streak', label: 'day streak'),
          _Stat(value: '$photos', label: photos == 1 ? 'photo' : 'photos'),
        ],
      ),
    );
  }
}

/// Consecutive days with at least one entry, ending [now]'s day — or the day
/// before, so a streak isn't shown as broken first thing in the morning
/// before today's entry has been written.
int diaryStreak(List<DiaryEntry> entries, DateTime now) {
  final days = {for (final e in entries) DateUtils.dateOnly(e.date)};
  var day = DateUtils.dateOnly(now);
  if (!days.contains(day)) day = DateUtils.addDaysToDate(day, -1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateUtils.addDaysToDate(day, -1);
  }
  return streak;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
