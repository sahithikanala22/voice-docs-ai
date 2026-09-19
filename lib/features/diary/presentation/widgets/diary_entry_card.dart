import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/diary_entry.dart';
import 'diary_page_background.dart';
import 'diary_photo.dart';

/// A diary entry as it appears in the list: a small version of its own themed
/// page, led by its first photo when it has one.
class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({super.key, required this.entry, required this.onTap});

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = entry.theme.style(Theme.of(context).colorScheme);
    final textTheme = Theme.of(context).textTheme;
    final title = entry.title.trim();
    final body = entry.body.trim();
    final mood = entry.mood;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: style.accent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: DiaryPageBackground(
            style: style,
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entry.photos.isNotEmpty)
                  SizedBox(
                    height: 170,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DiaryPhoto(name: entry.photos.first, decodeWidth: 900),
                        if (entry.photos.length > 1)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: _Badge(
                              icon: Icons.photo_library_rounded,
                              label: '${entry.photos.length}',
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('d').format(entry.date),
                            style: textTheme.headlineMedium?.copyWith(
                              color: style.accent,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(entry.date),
                                  style: textTheme.labelLarge?.copyWith(color: style.ink),
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(entry.date),
                                  style: textTheme.labelSmall?.copyWith(color: style.subtle),
                                ),
                              ],
                            ),
                          ),
                          if (mood != null)
                            Tooltip(
                              message: mood.label,
                              child: Text(mood.emoji, style: const TextStyle(fontSize: 26)),
                            ),
                        ],
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: style.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (body.isNotEmpty) ...[
                        SizedBox(height: title.isEmpty ? 12 : 4),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(color: style.subtle),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
