import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/widgets/brand_widgets.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';
import '../../domain/library_entry.dart';
import '../providers/library_providers.dart';
import '../widgets/library_entry_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  LibraryKind? _kind;
  LibraryPeriod _period = LibraryPeriod.all;
  String? _language, _folder;
  int _visible = 50;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(savedRecordingsProvider);
    }
  }

  void _reset() => setState(() {
    _kind = null;
    _period = LibraryPeriod.all;
    _language = null;
    _folder = null;
    _search.clear();
    _visible = 50;
  });
  void _refresh() {
    ref.invalidate(historyControllerProvider);
    ref.invalidate(diaryControllerProvider);
    ref.invalidate(taskControllerProvider);
    ref.invalidate(savedRecordingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(libraryProvider);
    final folders = ref.watch(folderControllerProvider).value ?? [];
    final languages =
        snapshot.entries
            .map((e) => e.language)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final filtered = LibraryFilter(
      query: _search.text,
      kind: _kind,
      period: _period,
      language: _language,
      folderId: _folder,
    ).apply(snapshot.entries, DateTime.now());
    final narrowed =
        _search.text.isNotEmpty ||
        _kind != null ||
        _period != LibraryPeriod.all ||
        _language != null ||
        _folder != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            onPressed: () => context.push('/history'),
            tooltip: 'Manage voice history',
            icon: const Icon(Icons.history_rounded),
          ),
          const SettingsAction(),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageIntroduction(
                      title: 'Find your words.',
                      subtitle:
                          'Voice notes, journal entries, tasks, and audio. All on this device.',
                    ),
                    TextField(
                      key: const ValueKey('library-search'),
                      controller: _search,
                      onChanged: (_) => setState(() => _visible = 50),
                      decoration: InputDecoration(
                        hintText: 'Search everything',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _visible = 50;
                                }),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _kind == null,
                          onSelected: (_) => setState(() {
                            _kind = null;
                            _visible = 50;
                          }),
                        ),
                        for (final kind in LibraryKind.values)
                          ChoiceChip(
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: (_) => setState(() {
                              _kind = kind;
                              _visible = 50;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        PopupMenuButton<LibraryPeriod>(
                          tooltip: 'Filter by date',
                          initialValue: _period,
                          onSelected: (v) => setState(() {
                            _period = v;
                            _visible = 50;
                          }),
                          itemBuilder: (_) => [
                            for (final p in LibraryPeriod.values)
                              PopupMenuItem(
                                value: p,
                                child: Text(_periodLabel(p)),
                              ),
                          ],
                          child: Chip(
                            avatar: const Icon(
                              Icons.date_range_outlined,
                              size: 18,
                            ),
                            label: Text(_periodLabel(_period)),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Filter by language',
                          onSelected: (v) => setState(() {
                            _language = v.isEmpty ? null : v;
                            _visible = 50;
                          }),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: '',
                              child: Text('All languages'),
                            ),
                            for (final language in languages)
                              PopupMenuItem(
                                value: language,
                                child: Text(languageByCode(language).name),
                              ),
                          ],
                          child: Chip(
                            avatar: const Icon(
                              Icons.translate_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _language == null
                                  ? 'All languages'
                                  : languageByCode(_language!).name,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Filter voice notes and audio by folder',
                          onSelected: (v) => setState(() {
                            _folder = v == '__all__' ? null : v;
                            _visible = 50;
                          }),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: '__all__',
                              child: Text('All folders'),
                            ),
                            const PopupMenuItem(
                              value: '',
                              child: Text('Unfiled'),
                            ),
                            for (final folder in folders)
                              PopupMenuItem(
                                value: folder.id,
                                child: Text(folder.name),
                              ),
                          ],
                          child: Chip(
                            avatar: const Icon(Icons.folder_outlined, size: 18),
                            label: Text(
                              _folder == null
                                  ? 'All folders'
                                  : _folder == ''
                                  ? 'Unfiled'
                                  : folderNameFor(folders, _folder),
                            ),
                          ),
                        ),
                        if (narrowed)
                          TextButton(
                            onPressed: _reset,
                            child: const Text('Reset filters'),
                          ),
                      ],
                    ),
                    if (snapshot.loading) const LinearProgressIndicator(),
                    if (snapshot.hasError)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text(
                            'Some saved items could not be loaded.',
                          ),
                          subtitle: const Text(
                            'Available results are shown. Your files have not been changed.',
                          ),
                          trailing: TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'item' : 'items'}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty && !snapshot.loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: Column(
                    children: [
                      const Icon(Icons.manage_search_rounded, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        narrowed
                            ? 'No matching items'
                            : 'Your words belong here',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        narrowed
                            ? 'Try another phrase or clear the filters.'
                            : 'Record a note or write a journal entry to get started.',
                        textAlign: TextAlign.center,
                      ),
                      if (narrowed)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: filtered.length.clamp(0, _visible),
                itemBuilder: (_, index) =>
                    LibraryEntryTile(entry: filtered[index]),
              ),
            ),
            if (filtered.length > _visible)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _visible += 50),
                    child: const Text('Show more'),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  String _periodLabel(LibraryPeriod p) => switch (p) {
    LibraryPeriod.all => 'Any date',
    LibraryPeriod.week => 'Last 7 days',
    LibraryPeriod.month => 'Last 30 days',
  };
}
