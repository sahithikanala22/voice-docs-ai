import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

/// One side of a translation exchange, styled like a modern chat bubble.
/// [filled] renders the gradient bubble used for the translated (target)
/// text; the source side uses an outlined bubble instead.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.languageLabel,
    required this.filled,
    required this.onSpeak,
    required this.onCopy,
  });

  final String text;
  final String languageLabel;
  final bool filled;
  final VoidCallback? onSpeak;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = filled ? scheme.onPrimary : scheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: filled ? null : scheme.surfaceContainerHigh,
        gradient: filled ? AppTheme.heroGradient(scheme) : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(filled ? 22 : 6),
          bottomRight: Radius.circular(filled ? 6 : 22),
        ),
        boxShadow: filled
            ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.isEmpty ? '…' : text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onSpeak,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.volume_up_rounded, size: 20, color: fg.withValues(alpha: 0.85)),
                  ),
                ),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy_rounded, size: 18, color: fg.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
