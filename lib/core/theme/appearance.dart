import 'package:flutter/material.dart';

/// User-selectable accent palette — each is the seed for a full Material 3
/// color scheme (light and dark), so one pick restyles every screen.
enum AppPalette {
  indigo('Indigo', Color(0xFF5B67F1)),
  sage('Sage', Color(0xFF6F8F5F)),
  rose('Rose', Color(0xFFD9779B)),
  lavender('Lavender', Color(0xFF8E7CE0)),
  midnight('Midnight', Color(0xFF2E3A6B)),
  gold('Gold', Color(0xFFC49A3C)),
  teal('Teal', Color(0xFF2A9D8F));

  const AppPalette(this.label, this.seed);

  final String label;
  final Color seed;
}

/// Background texture drawn behind every screen. [floatingDots] is the
/// original animated look and stays the default.
///
/// [customPhoto] is different from the rest: it has no fixed painter, it
/// renders whatever `AppSettings.backgroundPhotoPath` points at (dimmed for
/// legibility) — see `PaperBackground`.
enum PaperStyle {
  floatingDots('Floating dots'),
  plain('Plain'),
  aged('Aged'),
  parchment('Parchment'),
  waveLines('Wave lines'),
  dotGrid('Dot grid'),
  fineLinen('Fine linen'),
  customPhoto('Custom photo');

  const PaperStyle(this.label);

  final String label;
}
