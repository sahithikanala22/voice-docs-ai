import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/diary_entry.dart';
import '../../data/diary_local_datasource.dart';
import '../../data/diary_photo_store.dart';
import '../../data/diary_repository_impl.dart';
import '../../domain/diary_repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DiaryRepositoryImpl(DiaryLocalDataSource(prefs));
});

final diaryPhotoStoreProvider = Provider<DiaryPhotoStore>((ref) => DiaryPhotoStore());

/// Absolute path of the photo directory, resolved once so photo widgets can
/// build a `File` synchronously instead of each awaiting the platform.
final diaryPhotoDirProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(diaryPhotoStoreProvider).directory()).path,
);

/// Every diary entry, newest day first. Mutations persist immediately.
final diaryControllerProvider = AsyncNotifierProvider<DiaryController, List<DiaryEntry>>(
  DiaryController.new,
);

class DiaryController extends AsyncNotifier<List<DiaryEntry>> {
  @override
  Future<List<DiaryEntry>> build() => ref.watch(diaryRepositoryProvider).getAll();

  /// Saves [entry] and deletes the files for any photos it no longer uses.
  /// [removedPhotos] is passed in rather than diffed here because only the
  /// editor knows which of its photos were already saved versus added during
  /// this edit.
  Future<void> save(DiaryEntry entry, {Iterable<String> removedPhotos = const []}) async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.save(entry.copyWith(updatedAt: DateTime.now()));
    state = AsyncData(await repo.getAll());
    await ref.read(diaryPhotoStoreProvider).delete(removedPhotos);
  }

  Future<void> delete(DiaryEntry entry) async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.remove(entry.id);
    state = AsyncData(await repo.getAll());
    await ref.read(diaryPhotoStoreProvider).delete(entry.photos);
  }
}

/// Looks up one entry by id; null once it's been deleted.
final diaryEntryProvider = Provider.family<DiaryEntry?, String>((ref, id) {
  final entries = ref.watch(diaryControllerProvider).value ?? const [];
  for (final entry in entries) {
    if (entry.id == id) return entry;
  }
  return null;
});
