import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

import 'sound_wave_painter.dart';

/// Large, tap-to-toggle mic button with an ambient pulse when idle and a
/// sound-reactive pulse while actively listening.
class AnimatedMicButton extends StatefulWidget {
  const AnimatedMicButton({
    super.key,
    required this.isListening,
    required this.soundLevel,
    required this.onTap,
    this.size = 120,
  });

  final bool isListening;

  /// Raw device sound level (roughly -50..10 on iOS, 0..10 on Android) —
  /// normalization happens here so callers don't need to know the scale.
  final double soundLevel;
  final VoidCallback onTap;
  final double size;

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _normalizedLevel {
    if (!widget.isListening) return 0;
    return (widget.soundLevel / 10).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: widget.size * 2,
            height: widget.size * 2,
            child: CustomPaint(
              painter: SoundWavePainter(
                level: _normalizedLevel,
                colors: AppTheme.brandRays,
                animationValue: _controller.value,
              ),
              child: child,
            ),
          );
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isListening
                    ? [scheme.primary, scheme.tertiary]
                    : [scheme.primary.withValues(alpha: 0.9), scheme.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: widget.isListening ? 6 : 2,
                ),
              ],
            ),
            child: Icon(
              widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: scheme.onPrimary,
              size: widget.size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}
