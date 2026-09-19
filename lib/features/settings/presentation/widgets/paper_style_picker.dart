import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';

/// Grid of live-preview tiles, one per [PaperStyle], each drawn with the
/// same painter the real background uses so what you tap is what you get.
class PaperStylePicker extends StatelessWidget {
  const PaperStylePicker({super.key, required this.value, required this.onChanged});

  final PaperStyle value;
  final ValueChanged<PaperStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        for (final style in PaperStyle.values)
          _PaperTile(
            style: style,
            selected: style == value,
            ink: scheme.onSurface,
            isDark: isDark,
            onTap: () => onChanged(style),
          ),
      ],
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({
    required this.style,
    required this.selected,
    required this.ink,
    required this.isDark,
    required this.onTap,
  });

  final PaperStyle style;
  final bool selected;
  final Color ink;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: PaperPainter(style: style, ink: ink, isDark: isDark)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: (selected ? scheme.primaryContainer : scheme.surfaceContainerHighest)
                    .withValues(alpha: 0.9),
                child: Text(
                  style.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
