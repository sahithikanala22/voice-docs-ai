import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/paper_style.dart';

/// A grid of tappable cards, one per [PaperStyle] — each shows the style's
/// icon and label, with the selected one outlined. The "Custom Photo" tile
/// is special: tapping it always opens the image picker (via
/// [onPickCustomImage]) rather than just selecting it, and shows a
/// thumbnail of [customImagePath] once one's been chosen.
class PaperStylePicker extends StatelessWidget {
  const PaperStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onPickCustomImage,
    this.customImagePath,
  });

  final PaperStyle value;
  final ValueChanged<PaperStyle> onChanged;
  final VoidCallback onPickCustomImage;
  final String? customImagePath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customFile = customImagePath == null ? null : File(customImagePath!);
    final hasCustomImage = customFile?.existsSync() ?? false;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: PaperStyle.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final style = PaperStyle.values[index];
        final selected = style == value;
        final isCustomTile = style == PaperStyle.customImage;

        return Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isCustomTile ? onPickCustomImage : () => onChanged(style),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isCustomTile && hasCustomImage)
                  Image.file(customFile!, fit: BoxFit.cover),
                if (isCustomTile && hasCustomImage)
                  ColoredBox(
                    color: Colors.black.withValues(
                      alpha: selected ? 0.35 : 0.55,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        style.icon,
                        color: isCustomTile && hasCustomImage
                            ? Colors.white
                            : selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        style.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCustomTile && hasCustomImage
                              ? Colors.white
                              : selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
