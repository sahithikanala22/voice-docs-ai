import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/folder.dart';
import '../../data/folder_local_datasource.dart';
import '../../data/folder_repository_impl.dart';
import '../../domain/folder_repository.dart';

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FolderRepositoryImpl(FolderLocalDataSource(prefs));
});

/// Holds the full folder list, alphabetically sorted, and exposes mutation
/// methods that immediately persist and refresh state — the UI never talks
/// to the repository directly.
final folderControllerProvider =
    AsyncNotifierProvider<FolderController, List<Folder>>(FolderController.new);

class FolderController extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() {
    return ref.watch(folderRepositoryProvider).getAll();
  }

  /// Returns the newly created folder so callers can immediately select it
  /// as the current folder without a second round-trip.
  Future<Folder> addFolder(String name) async {
    final folder = Folder.create(name);
    await ref.read(folderRepositoryProvider).add(folder);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
    return folder;
  }

  Future<void> renameFolder(String id, String newName) async {
    await ref.read(folderRepositoryProvider).rename(id, newName);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
  }

  Future<void> removeFolder(String id) async {
    await ref.read(folderRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
  }
}

/// Resolves a folder id to its display name — "No folder" when [folderId] is
/// null, or when the folder was since deleted (its entries just fall back to
/// showing as unfiled rather than erroring).
String folderNameFor(List<Folder>? folders, String? folderId) {
  if (folderId == null) return 'No folder';
  final match = folders?.where((f) => f.id == folderId).firstOrNull;
  return match?.name ?? 'No folder';
}
