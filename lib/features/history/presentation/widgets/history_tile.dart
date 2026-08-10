import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/utils/time_ago.dart';

import '../../data/history_item.dart';

/// Swipe-to-delete row for one history entry — a voice transcript or a
/// translation pair, distinguished by a leading type icon.
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.item, required this.onTap, required this.onDelete});

  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  bool get _isTranslation => item.type == HistoryItemType.translation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sourceLang = languageByCode(item.sourceLanguageCode);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              _isTranslation ? Icons.translate_rounded : Icons.mic_rounded,
              color: scheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            item.sourceText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            _isTranslation
                ? '${sourceLang.name} → ${languageByCode(item.targetLanguageCode!).name}'
                : sourceLang.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            timeAgo(item.timestamp),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
