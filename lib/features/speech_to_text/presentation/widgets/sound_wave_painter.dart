import 'dart:math';

import 'package:flutter/material.dart';

/// Draws concentric pulse rings around the mic button, sized by the current
/// microphone amplitude, so the user gets real-time visual feedback while
/// speaking instead of a static icon. Each ring cycles through [colors] (the
/// logo's cyan-to-orange sound-wave palette) instead of one flat tint, so the
/// pulse reads as the same radiating burst as the app icon.
class SoundWavePainter extends CustomPainter {
  SoundWavePainter({required this.level, required this.colors, required this.animationValue});

  /// Roughly 0.0 (silence) .. 1.0 (loud), already normalized by the caller.
  final double level;
  final List<Color> colors;

  /// 0.0 .. 1.0 looping animation driver for a continuous ambient pulse.
  final double animationValue;

  static const _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final baseRadius = maxRadius * 0.55;

    for (var ring = 0; ring < _ringCount; ring++) {
      final ringProgress = ((animationValue + ring / _ringCount) % 1.0);
      final radius = baseRadius + (maxRadius - baseRadius) * ringProgress * (0.4 + level * 0.6);
      final opacity = (1 - ringProgress) * (0.15 + level * 0.25);
      final color = colors[ring % colors.length];

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0, 1))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, max(radius, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SoundWavePainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.animationValue != animationValue;
  }
}
