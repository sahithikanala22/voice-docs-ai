import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

/// A row of swatches for the app's accent/seed color — [value] null means
/// the default brand indigo (the first swatch, [AppTheme.accentPalette]'s
/// first entry). Mirrors the "Palette" row style of a notebook-app settings
/// screen: a circle per option, a ring around whichever is selected.
class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Color? value;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppTheme.accentPalette.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final color = AppTheme.accentPalette[index];
          final isDefault = index == 0;
          final selected = isDefault
              ? value == null
              : value?.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () => onChanged(isDefault ? null : color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
