import 'package:flutter/material.dart';

/// The background pattern shown behind every screen — mostly a purely
/// decorative, procedurally-drawn texture (no image assets, so choosing one
/// costs nothing in app size and needs no network) plus one exception,
/// [customImage], which shows a photo the user picked themselves.
enum PaperStyle {
  plain('Plain', Icons.crop_square_outlined),
  floatingDots('Floating Dots', Icons.blur_on_rounded),
  dotGrid('Dot Grid', Icons.grid_on_rounded),
  waveLines('Wave Lines', Icons.waves_rounded),
  agedPaper('Aged', Icons.description_outlined),
  parchment('Parchment', Icons.gradient_rounded),
  fineLinen('Fine Linen', Icons.texture_rounded),
  customImage('Custom Photo', Icons.add_photo_alternate_outlined);

  const PaperStyle(this.label, this.icon);

  final String label;
  final IconData icon;
}
