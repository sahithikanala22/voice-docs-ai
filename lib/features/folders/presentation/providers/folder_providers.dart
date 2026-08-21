import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';

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
  /// as the current folder without a second round-trip. [colorIndex]
  /// defaults to the next unused palette slot (round-robin by however many
  /// folders already exist) when the caller doesn't pick one explicitly.
  Future<Folder> addFolder(String name, {int? colorIndex}) async {
    final existingCount = state.value?.length ?? 0;
    final folder = Folder.create(
      name,
      colorIndex: colorIndex ?? (existingCount % AppTheme.folderPalette.length),
    );
    await ref.read(folderRepositoryProvider).add(folder);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
    return folder;
  }

  Future<void> updateFolder(String id, {String? name, int? colorIndex}) async {
    await ref.read(folderRepositoryProvider).update(id, name: name, colorIndex: colorIndex);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
  }

  Future<void> removeFolder(String id) async {
    await ref.read(folderRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(folderRepositoryProvider).getAll());
  }
}

/// Resolves a folder id to the [Folder] itself — null when [folderId] is
/// null, or when the folder was since deleted (its entries just fall back to
/// showing as unfiled rather than erroring).
Folder? folderByIdOrNull(List<Folder>? folders, String? folderId) {
  if (folderId == null) return null;
  return folders?.where((f) => f.id == folderId).firstOrNull;
}

/// Resolves a folder id to its display name — "No folder" when [folderId] is
/// null, or when the folder was since deleted.
String folderNameFor(List<Folder>? folders, String? folderId) {
  return folderByIdOrNull(folders, folderId)?.name ?? 'No folder';
}

/// Resolves a folder id to its assigned color, falling back to a neutral
/// gray for unfiled entries or a folder that's since been deleted.
Color folderColorFor(List<Folder>? folders, String? folderId) {
  final folder = folderByIdOrNull(folders, folderId);
  if (folder == null) return Colors.grey;
  return AppTheme.folderPalette[folder.colorIndex % AppTheme.folderPalette.length];
}
