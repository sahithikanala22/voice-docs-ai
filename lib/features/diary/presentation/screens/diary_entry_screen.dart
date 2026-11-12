import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import '../../data/diary_entry.dart';
import '../providers/diary_providers.dart';
import '../widgets/diary_page.dart';

class DiaryEntryScreen extends ConsumerWidget {
  const DiaryEntryScreen({super.key, required this.entryId});
  final String entryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(diaryControllerProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This entry could not be opened.')),
          ),
          data: (entries) {
            final entry = entries.where((e) => e.id == entryId).firstOrNull;
            if (entry == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('This entry no longer exists.')),
              );
            }
            return Theme(
              data: diaryTheme(context, entry.pageStyle),
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Diary entry'),
                      actions: [
                        IconButton(
                          tooltip: 'Edit entry',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              context.push('/diary-entry/$entryId/edit'),
                        ),
                        IconButton(
                          tooltip: 'Delete entry',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _delete(context, ref, entry),
                        ),
                      ],
                    ),
                    body: SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            DateFormat('EEEE, d MMMM yyyy').format(entry.date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (entry.mood != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: MoodLabel(mood: entry.mood!),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SelectableText(
                            entry.displayTitle,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontFamily: 'serif'),
                          ),
                          const SizedBox(height: 18),
                          SelectableText(
                            entry.body,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.7),
                          ),
                          for (final photo in entry.photos)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: GestureDetector(
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: InteractiveViewer(
                                      child: DiaryPhoto(
                                        path: photo,
                                        height: 420,
                                      ),
                                    ),
                                  ),
                                ),
                                child: DiaryPhoto(path: photo, height: 240),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DiaryEntry entry,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete diary entry?'),
        content: const Text(
          'This permanently removes this entry and its photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      final photos = ref.read(diaryPhotoStoreProvider);
      await ref.read(diaryControllerProvider.notifier).delete(entry.id);
      await photos.remove(entry.photos);
      if (context.mounted) {
        context.pop();
        AppSnackbar.show(context, 'Diary entry deleted');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Could not delete this entry. Try again.',
          isError: true,
        );
      }
    }
  }
}
