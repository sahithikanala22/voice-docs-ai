import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/theme/theme_presets.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';

/// A 2x2 grid of named theme presets ("Midnight", "Paper", "Vintage",
/// "Ocean") — a one-tap shortcut for the accent-color/paper-style/mode
/// pickers below it, for anyone who'd rather pick a whole look than mix and
/// match three separate settings.
class ThemePresetPicker extends StatelessWidget {
  const ThemePresetPicker({super.key, required this.settings, required this.onSelected});

  final AppSettings settings;
  final ValueChanged<ThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: [
        for (final preset in ThemePreset.values)
          _PresetTile(
            preset: preset,
            selected: preset.matches(settings),
            onTap: () => onSelected(preset),
          ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.selected, required this.onTap});

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewScheme = AppTheme.schemeFor(
      preset.palette,
      preset.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );
    final isDark = preset.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: previewScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PaperPainter(style: preset.paperStyle, ink: previewScheme.onSurface, isDark: isDark),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  _AccentDot(color: previewScheme.primary),
                  const SizedBox(width: 4),
                  _AccentDot(color: previewScheme.tertiary),
                  const SizedBox(width: 6),
                  Icon(preset.icon, size: 16, color: previewScheme.onSurface),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: (selected ? scheme.primaryContainer : scheme.surfaceContainerHighest)
                    .withValues(alpha: 0.9),
                child: Text(
                  preset.label,
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

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
