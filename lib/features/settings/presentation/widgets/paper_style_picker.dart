import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

/// Grid of live-preview tiles, one per [PaperStyle], each drawn with the
/// same painter the real background uses so what you tap is what you get.
///
/// The last tile, "Custom photo", is different: tapping it opens a picker
/// when there's no photo yet (or [onPickPhoto] is invoked to replace the
/// current one), rather than just selecting — that's what [onPickPhoto] is
/// for, kept separate from [onChanged] which only ever switches between the
/// fixed preset styles.
class PaperStylePicker extends StatelessWidget {
  const PaperStylePicker({
    super.key,
    required this.value,
    required this.backgroundPhotoPath,
    required this.onChanged,
    required this.onPickPhoto,
  });

  final PaperStyle value;
  final String? backgroundPhotoPath;
  final ValueChanged<PaperStyle> onChanged;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final presets = PaperStyle.values.where((s) => s != PaperStyle.customPhoto);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        for (final style in presets)
          _PaperTile(
            style: style,
            selected: style == value,
            ink: scheme.onSurface,
            isDark: isDark,
            onTap: () => onChanged(style),
          ),
        _CustomPhotoTile(
          path: backgroundPhotoPath,
          selected: value == PaperStyle.customPhoto,
          onTap: () {
            // A photo already picked: tapping just switches to it, same as
            // any other tile. Tapping again (already selected) or with no
            // photo yet both mean "pick/replace one".
            if (backgroundPhotoPath != null && value != PaperStyle.customPhoto) {
              onChanged(PaperStyle.customPhoto);
            } else {
              onPickPhoto();
            }
          },
        ),
      ],
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({
    required this.style,
    required this.selected,
    required this.ink,
    required this.isDark,
    required this.onTap,
  });

  final PaperStyle style;
  final bool selected;
  final Color ink;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      selected: selected,
      label: style.label,
      onTap: onTap,
      preview: CustomPaint(painter: PaperPainter(style: style, ink: ink, isDark: isDark)),
    );
  }
}

/// The "Custom photo" tile: shows the actual picked photo once there is one,
/// otherwise a plain "add a photo" hint.
class _CustomPhotoTile extends ConsumerWidget {
  const _CustomPhotoTile({required this.path, required this.selected, required this.onTap});

  final String? path;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dir = path == null ? null : ref.watch(appBackgroundPhotoDirProvider).value;

    return _TileFrame(
      selected: selected,
      label: 'Custom photo',
      onTap: onTap,
      preview: path != null && dir != null
          ? Image.file(
              File('$dir/$path'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AddPhotoHint(scheme: scheme),
            )
          : _AddPhotoHint(scheme: scheme),
    );
  }
}

class _AddPhotoHint extends StatelessWidget {
  const _AddPhotoHint({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.add_photo_alternate_outlined, color: scheme.onSurfaceVariant, size: 22),
    );
  }
}

/// The border/selection/label chrome shared by every tile — a plain preset
/// texture or the custom-photo thumbnail alike.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.preview,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: preview),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: (selected ? scheme.primaryContainer : scheme.surfaceContainerHighest)
                    .withValues(alpha: 0.9),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
