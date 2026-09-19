import 'dart:io';

import 'package:ai_voice_docs/core/data/image_file_store.dart';

/// Owns the file behind the app-wide custom background photo — same
/// [ImageFileStore] mechanics as diary photos and the profile avatar. Only
/// one file is ever current (`AppSettings.backgroundPhotoPath`); a
/// replacement gets a fresh name rather than overwriting in place, so a
/// swapped photo can't show stale cached bytes.
class AppBackgroundPhotoStore {
  AppBackgroundPhotoStore({Future<Directory> Function()? documentsDir})
    : _store = ImageFileStore('app_background', documentsDir: documentsDir);

  final ImageFileStore _store;

  Future<Directory> directory() => _store.directory();

  Future<String> import(String sourcePath) => _store.import(sourcePath, namePrefix: 'background');

  Future<void> delete(Iterable<String> names) => _store.delete(names);

  /// Deletes the stored background photo — used when a full app reset
  /// (forgotten PIN) wipes the settings that referenced it.
  Future<void> clearAll() => _store.clearAll();
}
