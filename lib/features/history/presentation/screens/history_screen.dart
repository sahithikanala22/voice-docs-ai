import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/floating_dots_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_filter_chip.dart';

import '../providers/history_providers.dart';
import '../widgets/history_detail_sheet.dart';
import '../widgets/history_tile.dart';
import '../widgets/share_format_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Which folder the list is filtered to: `null` = All, `''` = Unfiled,
  /// otherwise a folder id.
  String? _filterFolderId;

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);
    final foldersAsync = ref.watch(folderControllerProvider);
    final folders = foldersAsync.value ?? const [];

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel',
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                _selectedIds.isEmpty
                    ? 'Select entries'
                    : '${_selectedIds.length} selected',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete selected',
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _confirmDeleteSelected(context),
                ),
              ],
              bottom: const GradientAppBarUnderline(),
            )
          : AppBar(
              title: const Text('History'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Select',
                  onPressed: () => setState(() => _selectionMode = true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear all',
                  onPressed: () => _confirmClearAll(context),
                ),
              ],
              bottom: const GradientAppBarUnderline(),
            ),
      body: FloatingDotsBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 4),
                TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search history',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FolderFilterChip(
                          label: 'All',
                          selected: _filterFolderId == null,
                          onSelected: () =>
                              setState(() => _filterFolderId = null),
                        ),
                        const SizedBox(width: 8),
                        FolderFilterChip(
                          label: 'Unfiled',
                          selected: _filterFolderId == '',
                          onSelected: () =>
                              setState(() => _filterFolderId = ''),
                        ),
                        for (final folder in folders) ...[
                          const SizedBox(width: 8),
                          FolderFilterChip(
                            label: folder.name,
                            color: folderColorFor(folders, folder.id),
                            selected: _filterFolderId == folder.id,
                            onSelected: () =>
                                setState(() => _filterFolderId = folder.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: historyAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) =>
                        Center(child: Text('Could not load history: $err')),
                    data: (items) {
                      final filtered = items.where((e) {
                        final matchesQuery =
                            _query.isEmpty ||
                            e.sourceText.toLowerCase().contains(_query);
                        final matchesFolder =
                            _filterFolderId == null ||
                            (_filterFolderId == ''
                                ? e.folderId == null
                                : e.folderId == _filterFolderId);
                        return matchesQuery && matchesFolder;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No history yet',
                          subtitle: 'Your voice transcripts will show up here.',
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return HistoryTile(
                            item: item,
                            folder: folderByIdOrNull(folders, item.folderId),
                            selectionMode: _selectionMode,
                            selected: _selectedIds.contains(item.id),
                            onTap: () {
                              if (_selectionMode) {
                                setState(() {
                                  if (!_selectedIds.remove(item.id)) {
                                    _selectedIds.add(item.id);
                                  }
                                });
                              } else {
                                showHistoryDetailSheet(context, ref, item);
                              }
                            },
                            onDelete: () {
                              ref
                                  .read(historyControllerProvider.notifier)
                                  .removeEntry(item.id);
                              AppSnackbar.show(context, 'Removed from history');
                            },
                            onShare: () => showShareFormatSheet(context, item),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'entry' : 'entries'}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final notifier = ref.read(historyControllerProvider.notifier);
      for (final id in _selectedIds) {
        await notifier.removeEntry(id);
      }
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Deleted $count ${count == 1 ? 'entry' : 'entries'}',
        );
      }
      _exitSelectionMode();
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This removes every saved transcript. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(historyControllerProvider.notifier).clearAll();
    }
  }
}
