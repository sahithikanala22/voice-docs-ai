import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/widgets/folder_picker_sheet.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../../data/history_item.dart';
import '../../data/history_pdf_generator.dart';
import '../../data/history_word_generator.dart';
import '../providers/history_providers.dart';
import '../widgets/history_tile.dart';

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
              title: Text(_selectedIds.isEmpty ? 'Select entries' : '${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete selected',
                  onPressed: _selectedIds.isEmpty ? null : () => _confirmDeleteSelected(context),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
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
                      _FolderFilterChip(
                        label: 'All',
                        selected: _filterFolderId == null,
                        onSelected: () => setState(() => _filterFolderId = null),
                      ),
                      const SizedBox(width: 8),
                      _FolderFilterChip(
                        label: 'Unfiled',
                        selected: _filterFolderId == '',
                        onSelected: () => setState(() => _filterFolderId = ''),
                      ),
                      for (final folder in folders) ...[
                        const SizedBox(width: 8),
                        _FolderFilterChip(
                          label: folder.name,
                          selected: _filterFolderId == folder.id,
                          onSelected: () => setState(() => _filterFolderId = folder.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Could not load history: $err')),
                  data: (items) {
                    final filtered = items.where((e) {
                      final matchesQuery = _query.isEmpty ||
                          e.sourceText.toLowerCase().contains(_query) ||
                          (e.translatedText?.toLowerCase().contains(_query) ?? false);
                      final matchesFolder = _filterFolderId == null ||
                          (_filterFolderId == '' ? e.folderId == null : e.folderId == _filterFolderId);
                      return matchesQuery && matchesFolder;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No history yet',
                        subtitle: 'Your voice transcripts and translations will show up here.',
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return HistoryTile(
                          item: item,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(item.id),
                          onTap: () {
                            if (_selectionMode) {
                              setState(() {
                                if (!_selectedIds.remove(item.id)) _selectedIds.add(item.id);
                              });
                            } else {
                              _openDetail(context, item);
                            }
                          },
                          onDelete: () {
                            ref.read(historyControllerProvider.notifier).removeEntry(item.id);
                            AppSnackbar.show(context, 'Removed from history');
                          },
                          onShare: () => _chooseShareFormat(context, item),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final notifier = ref.read(historyControllerProvider.notifier);
      for (final id in _selectedIds) {
        await notifier.removeEntry(id);
      }
      if (context.mounted) {
        AppSnackbar.show(context, 'Deleted $count ${count == 1 ? 'entry' : 'entries'}');
      }
      _exitSelectionMode();
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('This removes every saved transcript and translation. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(historyControllerProvider.notifier).clearAll();
    }
  }

  void _openDetail(BuildContext context, HistoryItem item) {
    final isTranslation = item.type == HistoryItemType.translation;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        folderNameFor(ref.read(folderControllerProvider).value, item.folderId),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(languageByCode(item.sourceLanguageCode).name,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(item.sourceText, style: Theme.of(context).textTheme.titleMedium),
              if (isTranslation) ...[
                const Divider(height: 32),
                Text(languageByCode(item.targetLanguageCode!).name,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(item.translatedText ?? '', style: Theme.of(context).textTheme.titleMedium),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _moveToFolder(context, item),
                    icon: const Icon(Icons.drive_file_move_outlined),
                    label: const Text('Move to folder'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _shareGeneratedFile(
                      context,
                      () => HistoryPdfGenerator().generate(item),
                      'Could not create the PDF.',
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _shareGeneratedFile(
                      context,
                      () => HistoryWordGenerator().generate(item),
                      'Could not create the Word document.',
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Share Word'),
                  ),
                  FilledButton.icon(
                    onPressed: () => ref.read(ttsControllerProvider.notifier).speak(
                          isTranslation ? (item.translatedText ?? '') : item.sourceText,
                          languageByCode(isTranslation ? item.targetLanguageCode! : item.sourceLanguageCode)
                              .localeHint,
                        ),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _moveToFolder(BuildContext context, HistoryItem item) async {
    final result = await showFolderPicker(context, selectedFolderId: item.folderId);
    if (result == null) return;
    final newFolderId = result.isEmpty ? null : result;
    await ref.read(historyControllerProvider.notifier).moveToFolder(item.id, newFolderId);
    if (context.mounted) {
      Navigator.pop(context);
      AppSnackbar.show(
        context,
        'Moved to ${folderNameFor(ref.read(folderControllerProvider).value, newFolderId)}',
      );
    }
  }

  Future<void> _chooseShareFormat(BuildContext context, HistoryItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Share as PDF'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareGeneratedFile(
                    context,
                    () => HistoryPdfGenerator().generate(item),
                    'Could not create the PDF.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Share as Word'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareGeneratedFile(
                    context,
                    () => HistoryWordGenerator().generate(item),
                    'Could not create the Word document.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareGeneratedFile(
    BuildContext context,
    Future<File> Function() generate,
    String failureMessage,
  ) async {
    try {
      final file = await generate();
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Shared from Voice Docs AI');
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(context, failureMessage, isError: true);
      }
    }
  }
}

class _FolderFilterChip extends StatelessWidget {
  const _FolderFilterChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
