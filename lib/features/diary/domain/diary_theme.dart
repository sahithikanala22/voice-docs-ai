import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/appearance.dart';

/// The look of a single diary page. Every theme except [classic] carries its
/// own colors, like a physical notebook page — so a Midnight entry stays dark
/// and gold even when the app is in light mode.
enum DiaryTheme {
  classic('Classic'),
  blush('Blush'),
  sage('Sage'),
  sky('Sky'),
  lavender('Lavender'),
  sunset('Sunset'),
  parchment('Parchment'),
  kraft('Kraft'),
  midnight('Midnight');

  const DiaryTheme(this.label);

  final String label;

  /// Resolves the concrete colors. [scheme] is only consulted by [classic],
  /// which follows the app's own palette.
  DiaryThemeStyle style(ColorScheme scheme) => switch (this) {
    DiaryTheme.classic => DiaryThemeStyle(
      background: [scheme.surface, scheme.surfaceContainerLow],
      ink: scheme.onSurface,
      subtle: scheme.onSurfaceVariant,
      accent: scheme.primary,
      paper: PaperStyle.plain,
      isDark: scheme.brightness == Brightness.dark,
    ),
    DiaryTheme.blush => const DiaryThemeStyle(
      background: [Color(0xFFFFF1F3), Color(0xFFFBDDE6)],
      ink: Color(0xFF4A1D2B),
      subtle: Color(0xFF8C5A68),
      accent: Color(0xFFD9577A),
      paper: PaperStyle.dotGrid,
      isDark: false,
    ),
    DiaryTheme.sage => const DiaryThemeStyle(
      background: [Color(0xFFF0F4EC), Color(0xFFDCE7D3)],
      ink: Color(0xFF243322),
      subtle: Color(0xFF5B6D57),
      accent: Color(0xFF5E8C55),
      paper: PaperStyle.fineLinen,
      isDark: false,
    ),
    DiaryTheme.sky => const DiaryThemeStyle(
      background: [Color(0xFFEDF6FC), Color(0xFFD3E8F7)],
      ink: Color(0xFF13324A),
      subtle: Color(0xFF4E6B82),
      accent: Color(0xFF2F7EC2),
      paper: PaperStyle.waveLines,
      isDark: false,
    ),
    DiaryTheme.lavender => const DiaryThemeStyle(
      background: [Color(0xFFF5F0FC), Color(0xFFE4D9F7)],
      ink: Color(0xFF2E2345),
      subtle: Color(0xFF675A80),
      accent: Color(0xFF8062D4),
      paper: PaperStyle.dotGrid,
      isDark: false,
    ),
    DiaryTheme.sunset => const DiaryThemeStyle(
      background: [Color(0xFFFFEBD8), Color(0xFFFFD2C4), Color(0xFFF6C9DA)],
      ink: Color(0xFF4A2418),
      subtle: Color(0xFF85584A),
      accent: Color(0xFFE0692F),
      paper: PaperStyle.plain,
      isDark: false,
    ),
    DiaryTheme.parchment => const DiaryThemeStyle(
      background: [Color(0xFFF7EDD5), Color(0xFFEBDCB6)],
      ink: Color(0xFF3A2E1A),
      subtle: Color(0xFF6E5E40),
      accent: Color(0xFFA2772A),
      paper: PaperStyle.parchment,
      isDark: false,
    ),
    DiaryTheme.kraft => const DiaryThemeStyle(
      background: [Color(0xFFE6D2B2), Color(0xFFD5BC94)],
      ink: Color(0xFF3B2A14),
      subtle: Color(0xFF6B5535),
      accent: Color(0xFF8E5E26),
      paper: PaperStyle.aged,
      isDark: false,
    ),
    DiaryTheme.midnight => const DiaryThemeStyle(
      background: [Color(0xFF161C36), Color(0xFF0B0F24)],
      ink: Color(0xFFF2EBDD),
      subtle: Color(0xFFB4AC9C),
      accent: Color(0xFFE3B55B),
      paper: PaperStyle.aged,
      isDark: true,
    ),
  };
}

/// Concrete colors for one [DiaryTheme]. [ink] is chosen to stay readable on
/// every stop of [background].
class DiaryThemeStyle {
  const DiaryThemeStyle({
    required this.background,
    required this.ink,
    required this.subtle,
    required this.accent,
    required this.paper,
    required this.isDark,
  });

  final List<Color> background;
  final Color ink;
  final Color subtle;
  final Color accent;
  final PaperStyle paper;
  final bool isDark;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: background,
  );
}
