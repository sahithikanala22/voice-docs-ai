import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';

import '../../data/history_item.dart';

/// Swipe-to-delete row for one history entry — a voice transcript or a
/// translation pair, distinguished by a leading type icon.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

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
          contentPadding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMM d, h:mm a').format(item.timestamp),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                tooltip: 'Share',
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
