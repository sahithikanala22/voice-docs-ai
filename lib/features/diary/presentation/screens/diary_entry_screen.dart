import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../../data/diary_entry.dart';
import '../../domain/diary_theme.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_page_background.dart';
import '../widgets/diary_photo.dart';

/// Reads one diary entry as a full themed page.
class DiaryEntryScreen extends ConsumerWidget {
  const DiaryEntryScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(diaryEntryProvider(entryId));
    if (entry == null) {
      // Deleted, or a stale link — nothing to show.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This entry no longer exists.')),
      );
    }

    final style = entry.theme.style(Theme.of(context).colorScheme);
    final textTheme = Theme.of(context).textTheme;
    final mood = entry.mood;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: style.background.first,
        body: DiaryPageBackground(
          style: style,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: style.ink),
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: style.ink),
                        tooltip: 'Edit',
                        onPressed: () => context.push('/diary-entry/${entry.id}/edit'),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: style.ink),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, ref, entry),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormat('d').format(entry.date),
                            style: textTheme.displaySmall?.copyWith(
                              color: style.accent,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE').format(entry.date),
                                  style: textTheme.titleMedium?.copyWith(color: style.ink),
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(entry.date),
                                  style: textTheme.bodySmall?.copyWith(color: style.subtle),
                                ),
                              ],
                            ),
                          ),
                          if (mood != null)
                            Column(
                              children: [
                                Text(mood.emoji, style: const TextStyle(fontSize: 34)),
                                Text(
                                  mood.label,
                                  style: textTheme.labelSmall?.copyWith(color: style.subtle),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (entry.title.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          entry.title,
                          style: textTheme.headlineSmall?.copyWith(
                            color: style.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (entry.photos.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _PhotoGallery(photos: entry.photos, style: style),
                      ],
                      if (entry.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        SelectableText(
                          entry.body,
                          style: textTheme.bodyLarge?.copyWith(color: style.ink, height: 1.7),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          entry.photos.isEmpty
              ? 'This cannot be undone.'
              : 'Its ${entry.photos.length == 1 ? 'photo' : '${entry.photos.length} photos'} will be '
                    'deleted too. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Leave before deleting: this screen watches the entry, so deleting it
    // while still on screen would flash the "no longer exists" state. That
    // means grabbing the controller now — `ref` is unusable once popped — and
    // raising the snackbar now too; it lives on the app-wide messenger, so it
    // still shows over the diary list.
    final controller = ref.read(diaryControllerProvider.notifier);
    AppSnackbar.show(context, 'Entry deleted');
    context.pop();
    await controller.delete(entry);
  }
}

/// One photo full width; several in a two-column grid. Tapping opens the
/// fullscreen viewer at that photo.
class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.photos, required this.style});

  final List<String> photos;
  final DiaryThemeStyle style;

  @override
  Widget build(BuildContext context) {
    void open(int index) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(photos: photos, initialIndex: index),
      ),
    );

    Widget tile(int index, {double? height}) => GestureDetector(
      onTap: () => open(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          child: Hero(
            tag: 'diary-photo-${photos[index]}',
            child: DiaryPhoto(name: photos[index], decodeWidth: 1080),
          ),
        ),
      ),
    );

    if (photos.length == 1) return tile(0, height: 260);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => tile(index),
    );
  }
}

/// Swipe between photos, pinch to zoom.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: widget.photos.length > 1 ? Text('${_index + 1} of ${widget.photos.length}') : null,
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, index) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Hero(
                tag: 'diary-photo-${widget.photos[index]}',
                child: DiaryPhoto(name: widget.photos[index], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
