import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

/// A thin rainbow strip for `AppBar.bottom` — a small, consistent signature
/// touch across every screen that echoes the logo's sound-wave palette.
class GradientAppBarUnderline extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBarUnderline({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 3, decoration: BoxDecoration(gradient: AppTheme.rainbowGradient()));
  }

  @override
  Size get preferredSize => const Size.fromHeight(3);
}
