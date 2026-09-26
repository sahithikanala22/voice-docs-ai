import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_filter_chip.dart';

import '../providers/diary_providers.dart';
import '../widgets/diary_entry_card.dart';

/// A year-grouped browse of the whole diary, led by an "On this day" section —
/// the dedicated home for looking back, separate from the Diary tab's own
/// newest-first list.
class DiaryMemoriesScreen extends ConsumerStatefulWidget {
  const DiaryMemoriesScreen({super.key});

  @override
  ConsumerState<DiaryMemoriesScreen> createState() => _DiaryMemoriesScreenState();
}

class _DiaryMemoriesScreenState extends ConsumerState<DiaryMemoriesScreen> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(diaryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        bottom: const GradientAppBarUnderline(),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Could not load your diary: $err')),
            data: (entries) {
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'No memories yet',
                  subtitle: 'Write a few diary entries and this is where you\'ll look back on them.',
                );
              }

              final today = DateTime.now();
              final onThisDay =
                  entries
                      .where(
                        (e) => e.date.month == today.month && e.date.day == today.day && e.date.year != today.year,
                      )
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              final years = {for (final e in entries) e.date.year}.toList()..sort((a, b) => b.compareTo(a));
              final visible = _selectedYear == null
                  ? entries
                  : entries.where((e) => e.date.year == _selectedYear).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (onThisDay.isNotEmpty) ...[
                    Text('On this day', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final entry in onThisDay)
                      DiaryEntryCard(
                        key: ValueKey('otd-${entry.id}'),
                        entry: entry,
                        onTap: () => context.push('/diary-entry/${entry.id}'),
                      ),
                    const SizedBox(height: 8),
                  ],
                  Text('Your memories', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FolderFilterChip(
                        label: 'All',
                        selected: _selectedYear == null,
                        onSelected: () => setState(() => _selectedYear = null),
                      ),
                      for (final year in years)
                        FolderFilterChip(
                          label: '$year',
                          selected: _selectedYear == year,
                          onSelected: () => setState(() => _selectedYear = year),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final entry in visible)
                    DiaryEntryCard(
                      key: ValueKey(entry.id),
                      entry: entry,
                      onTap: () => context.push('/diary-entry/${entry.id}'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
