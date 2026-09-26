import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';

/// A one-tap bundle of [AppSettings.themeMode]/[AppSettings.palette]/
/// [AppSettings.paperStyle] — a named "look" someone can recognize at a
/// glance, sitting above the individual pickers for people who'd rather not
/// mix-and-match those three axes themselves. Picking one just writes the
/// three existing fields; nothing new is persisted for "which preset is
/// active" — see [matches].
enum ThemePreset {
  midnight('Midnight', Icons.dark_mode_rounded, ThemeMode.dark, AppPalette.midnight, PaperStyle.plain),
  paper('Paper', Icons.description_outlined, ThemeMode.light, AppPalette.indigo, PaperStyle.floatingDots),
  vintage('Vintage', Icons.auto_stories_outlined, ThemeMode.light, AppPalette.gold, PaperStyle.parchment),
  ocean('Ocean', Icons.waves_rounded, ThemeMode.light, AppPalette.teal, PaperStyle.waveLines);

  const ThemePreset(this.label, this.icon, this.themeMode, this.palette, this.paperStyle);

  final String label;
  final IconData icon;
  final ThemeMode themeMode;
  final AppPalette palette;
  final PaperStyle paperStyle;

  /// Whether [settings] currently matches this preset exactly. Dynamic color
  /// (Material You) is checked too — it visually overrides the palette
  /// entirely, so no preset should read as "active" while it's on, even if
  /// mode/palette/paperStyle happen to coincide (same reasoning the palette
  /// picker uses to disable itself when dynamic color is on).
  bool matches(AppSettings settings) =>
      !settings.useDynamicColor &&
      settings.themeMode == themeMode &&
      settings.palette == palette &&
      settings.paperStyle == paperStyle;
}
