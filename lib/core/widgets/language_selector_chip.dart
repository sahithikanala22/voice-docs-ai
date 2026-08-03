import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:voxi_translate/core/models/language.dart';

/// Pill-shaped control showing a flag + language name, used on the
/// voice-to-text and translator screens to open the language picker.
class LanguageSelectorChip extends StatelessWidget {
  const LanguageSelectorChip({
    super.key,
    required this.language,
    required this.onTap,
  });

  final Language language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Flag.fromString(
                  language.flagCountryCode,
                  height: 20,
                  width: 20,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(language.name, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
