import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';

import '../../data/history_item.dart';

/// Swipe-to-delete row for one history entry — a voice transcript or a
/// translation pair, distinguished by a leading type icon. In
/// [selectionMode], the leading icon becomes a checkbox and tapping toggles
/// selection instead of opening the entry; swipe-to-delete is disabled so it
/// can't be confused with, or fight, the multi-select gesture.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    this.selectionMode = false,
    this.selected = false,
  });

  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final bool selectionMode;
  final bool selected;

  bool get _isTranslation => item.type == HistoryItemType.translation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sourceLang = languageByCode(item.sourceLanguageCode);

    return Dismissible(
      key: ValueKey(item.id),
      direction: selectionMode ? DismissDirection.none : DismissDirection.endToStart,
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
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
          leading: selectionMode
              ? Checkbox(value: selected, onChanged: (_) => onTap())
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isTranslation
                          ? [AppTheme.brandRays[2], AppTheme.brandRays[3]]
                          : [AppTheme.brandRays[0], AppTheme.brandRays[1]],
                    ),
                  ),
                  child: Icon(
                    _isTranslation ? Icons.translate_rounded : Icons.mic_rounded,
                    color: Colors.white,
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
          trailing: selectionMode
              ? null
              : Row(
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
