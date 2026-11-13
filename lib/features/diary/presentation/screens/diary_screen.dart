import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/widgets/brand_widgets.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import '../../data/diary_entry.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_page.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(diaryControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: const [SettingsAction()],
      ),
      body: PaperBackground(
        child: SafeArea(
          child: entries.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your diary could not be opened.'),
                  TextButton(
                    onPressed: () => ref.invalidate(diaryControllerProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (all) {
              final now = DateTime.now();
              final monthCount = all
                  .where(
                    (e) => e.date.month == now.month && e.date.year == now.year,
                  )
                  .length;
              final visible = all
                  .where(
                    (e) =>
                        _query.isEmpty ||
                        e.title.toLowerCase().contains(_query) ||
                        e.body.toLowerCase().contains(_query),
                  )
                  .toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: visible.isEmpty ? 2 : visible.length + 1,
                itemBuilder: (context, row) {
                  if (row == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PageIntroduction(
                          title: 'A little of every day.',
                          subtitle:
                              'A place for your words, photos, and memories.',
                        ),
                        Text(
                          '$monthCount ${monthCount == 1 ? 'entry' : 'entries'} this month',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    context.push('/diary-entry/new'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Write entry'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push(
                                  '/diary-entry/new',
                                  extra: {'dictate': true},
                                ),
                                icon: const Icon(Icons.mic_none_rounded),
                                label: const Text('Dictate'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _search,
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Search your diary',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  if (visible.isEmpty) {
                    return SizedBox(
                      height: 280,
                      child: EmptyState(
                        icon: _query.isEmpty
                            ? Icons.auto_stories_outlined
                            : Icons.search_off_rounded,
                        title: _query.isEmpty
                            ? 'Start your diary'
                            : 'No matching entries',
                        subtitle: _query.isEmpty
                            ? 'Write or dictate your first entry.'
                            : 'Try another word or clear your search.',
                      ),
                    );
                  }
                  final index = row - 1;
                  final entry = visible[index];
                  final showMonth =
                      index == 0 ||
                      visible[index - 1].date.month != entry.date.month ||
                      visible[index - 1].date.year != entry.date.year;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showMonth)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            DateFormat('MMMM yyyy').format(entry.date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      _DiaryCard(entry: entry),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry});
  final DiaryEntry entry;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/diary-entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  children: [
                    Text(
                      DateFormat('d').format(entry.date),
                      style: text.headlineMedium,
                    ),
                    Text(
                      DateFormat('EEE').format(entry.date).toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontFamily: 'serif',
                        fontSize: 19,
                      ),
                    ),
                    if (entry.body.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        entry.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.mood != null) ...[
                      const SizedBox(height: 10),
                      MoodLabel(mood: entry.mood!),
                    ],
                  ],
                ),
              ),
              if (entry.photos.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 62,
                  child: DiaryPhoto(path: entry.photos.first, height: 90),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
