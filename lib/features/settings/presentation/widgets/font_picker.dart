import 'package:flutter/material.dart';

import 'package:ai_voice_docs/core/theme/app_theme.dart';

/// One row per [AppTheme.fontChoices] entry, each previewing a sample
/// phrase set in that actual font — so picking a font shows what it looks
/// like rather than just naming it.
class FontPicker extends StatelessWidget {
  const FontPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RadioGroup<String?>(
      groupValue: value,
      onChanged: onChanged,
      child: Column(
        children: [
          for (final choice in AppTheme.fontChoices)
            RadioListTile<String?>(
              value: choice.family,
              title: Text(choice.label),
              subtitle: Text(
                'The quiet hours are mine',
                style: TextStyle(
                  fontFamily: choice.family,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
