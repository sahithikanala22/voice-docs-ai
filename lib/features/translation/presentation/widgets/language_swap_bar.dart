import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/language_selector_chip.dart';

/// Source ⇄ target language row with a swap button between them, matching
/// the reference app's language-pair control above the translation bubbles.
class LanguageSwapBar extends StatelessWidget {
  const LanguageSwapBar({
    super.key,
    required this.source,
    required this.target,
    required this.onTapSource,
    required this.onTapTarget,
    required this.onSwap,
  });

  final Language source;
  final Language target;
  final VoidCallback onTapSource;
  final VoidCallback onTapTarget;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: LanguageSelectorChip(language: source, onTap: onTapSource)),
        IconButton.filledTonal(
          onPressed: onSwap,
          icon: const Icon(Icons.swap_horiz_rounded),
          style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHigh),
        ),
        Expanded(child: LanguageSelectorChip(language: target, onTap: onTapTarget)),
      ],
    );
  }
}
