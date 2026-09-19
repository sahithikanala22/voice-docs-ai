import 'dart:io';

import 'package:ai_voice_docs/core/data/image_file_store.dart';

/// Owns the files behind diary photos — thin, diary-flavored wrapper over
/// the shared [ImageFileStore]; see its doc comment for the actual file
/// lifecycle (copy-in, timestamped names, delete, wipe-on-reset).
class DiaryPhotoStore {
  DiaryPhotoStore({Future<Directory> Function()? documentsDir})
    : _store = ImageFileStore('diary_photos', documentsDir: documentsDir);

  final ImageFileStore _store;

  Future<Directory> directory() => _store.directory();

  Future<String> import(String sourcePath) => _store.import(sourcePath, namePrefix: 'photo');

  Future<void> delete(Iterable<String> names) => _store.delete(names);

  /// Deletes every stored photo — used when a full app reset (forgotten PIN)
  /// wipes the diary entries themselves, so their photos don't linger as
  /// orphaned files with nothing left to reference them.
  Future<void> clearAll() => _store.clearAll();
}
