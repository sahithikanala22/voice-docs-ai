import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/widgets/paper_background.dart';

import '../../domain/diary_theme.dart';

/// Paints a diary page: the theme's gradient with its paper texture on top,
/// drawn by the same [PaperPainter] that backs the app-wide paper styles.
class DiaryPageBackground extends StatelessWidget {
  const DiaryPageBackground({super.key, required this.style, required this.child, this.borderRadius});

  final DiaryThemeStyle style;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(gradient: style.gradient, borderRadius: borderRadius),
      clipBehavior: borderRadius == null ? Clip.none : Clip.antiAlias,
      child: CustomPaint(
        painter: PaperPainter(style: style.paper, ink: style.ink, isDark: style.isDark),
        child: child,
      ),
    );
  }
}
