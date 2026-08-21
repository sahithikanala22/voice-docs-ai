import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/features/folders/data/folder.dart';

import '../../data/history_item.dart';

/// Swipe-to-delete row for one saved voice transcript. In [selectionMode],
/// the leading icon becomes a checkbox and tapping toggles selection instead
/// of opening the entry; swipe-to-delete is disabled so it can't be confused
/// with, or fight, the multi-select gesture.
///
/// When [folder] is set, a colored bar down the card's left edge plus a
/// matching name pill under the subtitle make the folder identifiable at a
/// glance while scanning the list, not just from the filter chips above it.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    this.folder,
    this.selectionMode = false,
    this.selected = false,
  });

  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final Folder? folder;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sourceLang = languageByCode(item.sourceLanguageCode);
    final folderColor =
        folder == null ? null : AppTheme.folderPalette[folder!.colorIndex % AppTheme.folderPalette.length];

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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (folderColor != null) Container(width: 5, color: folderColor),
              Expanded(
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
                              colors: [AppTheme.brandRays[0], AppTheme.brandRays[1]],
                            ),
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                        ),
                  title: Text(
                    item.sourceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sourceLang.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (folder != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: folderColor!.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            folder!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: folderColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: selectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.reminderAt != null) ...[
                              Icon(Icons.notifications_active_rounded, size: 14, color: scheme.primary),
                              const SizedBox(width: 4),
                            ],
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
            ],
          ),
        ),
      ),
    );
  }
}
