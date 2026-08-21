import 'package:flutter/material.dart';

/// A folder-colored choice chip, used to filter a list by folder — shared by
/// History and Calendar so the same "All / Unfiled / [folder]" row looks and
/// behaves identically everywhere it appears.
class FolderFilterChip extends StatelessWidget {
  const FolderFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
