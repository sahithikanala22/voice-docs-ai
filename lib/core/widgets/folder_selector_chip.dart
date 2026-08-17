import 'package:flutter/material.dart';

/// Pill-shaped control showing a folder icon + name, used on the
/// voice-to-text and translator screens to pick which folder new entries
/// save into — mirrors [LanguageSelectorChip]'s look and interaction.
class FolderSelectorChip extends StatelessWidget {
  const FolderSelectorChip({super.key, required this.folderName, required this.onTap});

  final String folderName;
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
              Icon(Icons.folder_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(folderName, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
