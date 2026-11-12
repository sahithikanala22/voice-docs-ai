import 'package:flutter/material.dart';

/// A quiet divider lets the icon and recording controls carry the brand color.
class GradientAppBarUnderline extends StatelessWidget
    implements PreferredSizeWidget {
  const GradientAppBarUnderline({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
    child: const SizedBox(height: 1, width: double.infinity),
  );
  @override
  Size get preferredSize => const Size.fromHeight(1);
}
