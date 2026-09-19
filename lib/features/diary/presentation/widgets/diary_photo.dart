import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/diary_providers.dart';

/// One stored diary photo, looked up by file name.
///
/// [decodeWidth] should be set wherever the photo is shown small (cards,
/// thumbnails): phone photos are several thousand pixels wide, and decoding
/// every one at full size in a scrolling list is what makes it stutter.
///
/// A photo whose file is gone — e.g. an entry restored from a backup on a new
/// phone, which carries the text but not the images — shows a placeholder
/// instead of throwing.
class DiaryPhoto extends ConsumerWidget {
  const DiaryPhoto({super.key, required this.name, this.fit = BoxFit.cover, this.decodeWidth});

  final String name;
  final BoxFit fit;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dir = ref.watch(diaryPhotoDirProvider).value;
    if (dir == null) return const _PhotoPlaceholder(loading: true);

    return Image.file(
      File('$dir/$name'),
      fit: fit,
      cacheWidth: decodeWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
