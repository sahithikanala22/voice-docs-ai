import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

import 'floating_dots_background.dart';

/// Draws the user's chosen [PaperStyle] behind [child]. Always builds the
/// same `Stack` shape (background at index 0, [child] at index 1) so picking
/// a different style never rebuilds the screen content — the Settings list,
/// for instance, keeps its scroll position while you try textures.
class PaperBackground extends ConsumerWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style =
        ref.watch(settingsControllerProvider.select((s) => s.value?.paperStyle)) ??
            PaperStyle.floatingDots;
    final scheme = Theme.of(context).colorScheme;

    final Widget background = switch (style) {
      PaperStyle.floatingDots => const FloatingDotsLayer(),
      PaperStyle.plain => const SizedBox.expand(),
      _ => RepaintBoundary(
          child: CustomPaint(
            painter: PaperPainter(
              style: style,
              ink: scheme.onSurface,
              isDark: scheme.brightness == Brightness.dark,
            ),
            size: Size.infinite,
          ),
        ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(style), child: background),
          ),
        ),
        child,
      ],
    );
  }
}

/// Static textures for each [PaperStyle]. Everything is deterministic (fixed
/// seeds), so a texture looks identical every time it's drawn, and is only
/// repainted when the style or theme colors change.
class PaperPainter extends CustomPainter {
  const PaperPainter({required this.style, required this.ink, required this.isDark});

  final PaperStyle style;

  /// Foreground color of the current theme — line/dot textures are drawn in
  /// this at very low alpha so they read as texture, never as content.
  final Color ink;
  final bool isDark;

  Color get _warm => isDark ? const Color(0xFFD9B26A) : const Color(0xFF8B6B3D);

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PaperStyle.floatingDots:
        _paintDots(canvas, size);
      case PaperStyle.plain:
        break;
      case PaperStyle.aged:
        _paintAged(canvas, size);
      case PaperStyle.parchment:
        _paintParchment(canvas, size);
      case PaperStyle.waveLines:
        _paintWaves(canvas, size);
      case PaperStyle.dotGrid:
        _paintDotGrid(canvas, size);
      case PaperStyle.fineLinen:
        _paintLinen(canvas, size);
    }
  }

  // Static version of the animated dots — used for the Settings preview tile.
  void _paintDots(Canvas canvas, Size size) {
    final random = Random(7);
    for (var i = 0; i < 16; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        2 + random.nextDouble() * 4,
        Paint()..color = AppTheme.brandRays[random.nextInt(AppTheme.brandRays.length)].withValues(alpha: 0.22),
      );
    }
  }

  void _paintAged(Canvas canvas, Size size) {
    final random = Random(11);
    final specks = (size.width * size.height / 5200).clamp(8, 160).toInt();
    for (var i = 0; i < specks; i++) {
      final center = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final radius = 0.8 + random.nextDouble() * 2.2;
      final aspect = 1 + random.nextDouble() * 1.8;
      final alpha = (isDark ? 0.10 : 0.08) + random.nextDouble() * (isDark ? 0.20 : 0.14);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 2 * aspect, height: radius * 2),
        Paint()..color = _warm.withValues(alpha: alpha),
      );
    }
  }

  void _paintParchment(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [_warm.withValues(alpha: 0), _warm.withValues(alpha: isDark ? 0.16 : 0.20)],
          stops: const [0.4, 1],
        ).createShader(rect),
    );
  }

  void _paintWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 22.0;
    for (var i = -8; i * spacing < size.height + size.width * 0.25; i++) {
      final path = Path();
      for (var x = -10.0; x <= size.width + 10; x += 6) {
        final y = i * spacing + x * 0.18 + sin(x / 42 + i * 0.5) * 9;
        x == -10 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintDotGrid(Canvas canvas, Size size) {
    const spacing = 22.0;
    final points = <Offset>[
      for (var y = spacing / 2; y < size.height; y += spacing)
        for (var x = spacing / 2; x < size.width; x += spacing) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = ink.withValues(alpha: 0.16)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLinen(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.045)
      ..strokeWidth = 0.7;
    const spacing = 4.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.ink != ink || oldDelegate.isDark != isDark;
}
