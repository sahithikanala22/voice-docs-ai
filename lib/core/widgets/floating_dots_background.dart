import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps [child] with a field of small, slowly drifting dots behind it —
/// used on the PIN entry screen so an otherwise bare security gate feels a
/// little more alive without distracting from actually entering the PIN.
/// Pure [CustomPainter] animation, no extra dependencies.
class FloatingDotsBackground extends StatefulWidget {
  const FloatingDotsBackground({super.key, required this.child, this.dotCount = 26});

  final Widget child;
  final int dotCount;

  @override
  State<FloatingDotsBackground> createState() => _FloatingDotsBackgroundState();
}

class _FloatingDotsBackgroundState extends State<FloatingDotsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 50))..repeat();
  late final List<_Dot> _dots = _generateDots(widget.dotCount);

  List<_Dot> _generateDots(int count) {
    // Fixed seed: the same pleasant, non-overlapping-looking layout every
    // time the lock screen appears, rather than a jarring reshuffle.
    final random = Random(7);
    return List.generate(count, (_) {
      return _Dot(
        origin: Offset(random.nextDouble(), random.nextDouble()),
        drift: Offset(
          (random.nextDouble() - 0.5) * 0.5,
          (random.nextDouble() - 0.5) * 0.5,
        ),
        radius: 2 + random.nextDouble() * 4,
        color: AppTheme.brandRays[random.nextInt(AppTheme.brandRays.length)],
        phase: random.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(painter: _DotsPainter(_dots, _controller.value)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Dot {
  _Dot({required this.origin, required this.drift, required this.radius, required this.color, required this.phase});

  final Offset origin;
  final Offset drift;
  final double radius;
  final Color color;
  final double phase;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.dots, this.progress);

  final List<_Dot> dots;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final dot in dots) {
      // Each dot oscillates back and forth around its origin on its own
      // phase offset, rather than sliding in one direction forever.
      final wave = sin((progress + dot.phase) * 2 * pi);
      final dx = (dot.origin.dx + dot.drift.dx * wave).clamp(0.0, 1.0);
      final dy = (dot.origin.dy + dot.drift.dy * wave).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        dot.radius,
        Paint()..color = dot.color.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => oldDelegate.progress != progress;
}
