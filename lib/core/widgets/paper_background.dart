import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

import '../theme/paper_style.dart';
import 'floating_dots_background.dart';

/// Wraps [child] with whichever [PaperStyle] is chosen in Settings —
/// replaces the single hard-coded floating-dots look with a menu of
/// procedurally-drawn textures (no image assets, so choosing one costs
/// nothing in app size). All but "Floating Dots" paint once and never
/// repaint, so having every bottom-nav tab mounted at once stays cheap.
class PaperBackground extends ConsumerWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).value;
    final style = settings?.paperStyle ?? PaperStyle.plain;

    if (style == PaperStyle.plain) return child;
    if (style == PaperStyle.floatingDots) {
      return FloatingDotsBackground(child: child);
    }

    if (style == PaperStyle.customImage) {
      final path = settings?.customBackgroundPath;
      final file = path == null ? null : File(path);
      if (file == null || !file.existsSync()) return child;
      // A scrim tinted from the current color scheme (not a fixed
      // black/white) so cards and text painted with scheme colors stay
      // legible over any photo, in both light and dark mode.
      final scrimColor = Theme.of(context).colorScheme.surface;
      return Stack(
        children: [
          Positioned.fill(child: Image.file(file, fit: BoxFit.cover)),
          Positioned.fill(
            child: ColoredBox(color: scrimColor.withValues(alpha: 0.62)),
          ),
          child,
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _painterFor(style))),
        child,
      ],
    );
  }

  CustomPainter _painterFor(PaperStyle style) {
    switch (style) {
      case PaperStyle.dotGrid:
        return const _DotGridPainter();
      case PaperStyle.waveLines:
        return const _WaveLinesPainter();
      case PaperStyle.agedPaper:
        return const _AgedPaperPainter();
      case PaperStyle.parchment:
        return const _ParchmentPainter();
      case PaperStyle.fineLinen:
        return const _FineLinenPainter();
      case PaperStyle.plain:
      case PaperStyle.floatingDots:
      case PaperStyle.customImage:
        throw StateError('handled above');
    }
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withValues(alpha: 0.14);
    for (double y = _spacing / 2; y < size.height; y += _spacing) {
      for (double x = _spacing / 2; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

class _WaveLinesPainter extends CustomPainter {
  const _WaveLinesPainter();

  static const _lineSpacing = 32.0;
  static const _amplitude = 4.0;
  static const _wavelength = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double y = _lineSpacing; y < size.height; y += _lineSpacing) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 4) {
        path.lineTo(x, y + _amplitude * sin((x / _wavelength) * 2 * pi));
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveLinesPainter oldDelegate) => false;
}

class _AgedPaperPainter extends CustomPainter {
  const _AgedPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFFE8D2A0).withValues(alpha: 0.10),
    );

    // Fixed seed so the "age spots" look the same every time this screen
    // appears, rather than reshuffling on each rebuild.
    final random = Random(11);
    for (var i = 0; i < 18; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 20 + random.nextDouble() * 60;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF8B6B3D).withValues(alpha: 0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgedPaperPainter oldDelegate) => false;
}

class _ParchmentPainter extends CustomPainter {
  const _ParchmentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFFF3E9D2).withValues(alpha: 0.16),
        const Color(0xFF8B6B3D).withValues(alpha: 0.12),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _ParchmentPainter oldDelegate) => false;
}

class _FineLinenPainter extends CustomPainter {
  const _FineLinenPainter();

  static const _spacing = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += _spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FineLinenPainter oldDelegate) => false;
}
