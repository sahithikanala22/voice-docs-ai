import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/widgets/empty_state.dart';

/// The scrollable transcript surface plus its action bar (copy / clear /
/// speak / share) — the modernized equivalent of the reference app's white
/// text box with icon row underneath.
class TranscriptCard extends StatelessWidget {
  const TranscriptCard({
    super.key,
    required this.transcript,
    required this.onCopy,
    required this.onClear,
    required this.onSpeak,
    required this.onShare,
  });

  final String transcript;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final VoidCallback onSpeak;
  final VoidCallback onShare;

  bool get _hasContent => transcript.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _hasContent
                  ? SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          transcript,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    )
                  : const EmptyState(
                      icon: Icons.mic_none_rounded,
                      title: 'Tap the mic to start speaking',
                      subtitle: 'Your words will appear here in real time.',
                    ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ActionIcon(icon: Icons.copy_rounded, label: 'Copy', onTap: _hasContent ? onCopy : null),
                ),
                Expanded(
                  child:
                      _ActionIcon(icon: Icons.close_rounded, label: 'Clear', onTap: _hasContent ? onClear : null),
                ),
                Expanded(
                  child: _ActionIcon(
                      icon: Icons.volume_up_rounded, label: 'Speak', onTap: _hasContent ? onSpeak : null),
                ),
                Expanded(
                  child:
                      _ActionIcon(icon: Icons.share_rounded, label: 'Share', onTap: _hasContent ? onShare : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: enabled ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
