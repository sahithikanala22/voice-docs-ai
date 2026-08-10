import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/empty_state.dart';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';

import '../../data/history_item.dart';
import '../../data/history_pdf_generator.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: () => _confirmClearAll(context),
          ),
        ],
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
              const SizedBox(height: 16),
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Could not load history: $err')),
                  data: (items) {
                    final filtered = _query.isEmpty
                        ? items
                        : items
                            .where((e) =>
                                e.sourceText.toLowerCase().contains(_query) ||
                                (e.translatedText?.toLowerCase().contains(_query) ?? false))
                            .toList();

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
                          onTap: () => _openDetail(context, item),
                          onDelete: () {
                            ref.read(historyControllerProvider.notifier).removeEntry(item.id);
                            AppSnackbar.show(context, 'Removed from history');
                          },
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportAndShare(context, item),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Share PDF'),
                  ),
                  const SizedBox(width: 12),
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

  Future<void> _exportAndShare(BuildContext context, HistoryItem item) async {
    try {
      final file = await HistoryPdfGenerator().generate(item);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Shared from Voice Docs AI');
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(context, 'Could not create the PDF.', isError: true);
      }
    }
  }
}
