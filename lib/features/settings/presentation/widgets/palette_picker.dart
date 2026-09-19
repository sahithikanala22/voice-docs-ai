import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/appearance.dart';

/// A scrollable row of color circles — one per [AppPalette] — with a ring
/// around the selected one.
class PalettePicker extends StatelessWidget {
  const PalettePicker({super.key, required this.value, required this.onChanged, this.enabled = true});

  final AppPalette value;
  final ValueChanged<AppPalette> onChanged;

  /// False while wallpaper (Material You) colors are on, since those override
  /// the palette entirely.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AppPalette.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final palette = AppPalette.values[index];
            final selected = palette == value;
            return Tooltip(
              message: palette.label,
              child: GestureDetector(
                onTap: enabled ? () => onChanged(palette) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: palette.seed),
                    child: selected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
