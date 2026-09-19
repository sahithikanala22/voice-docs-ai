import 'dart:io';

import 'package:ai_voice_docs/core/data/image_file_store.dart';

/// Owns the file behind the profile picture — same [ImageFileStore]
/// mechanics as diary photos, own subdirectory. Only one file is ever
/// "current" ([AppLockAccount.avatarPath]), but old ones aren't overwritten
/// in place: each pick gets a fresh name so a replaced picture can't show
/// stale cached bytes, and the previous file is deleted explicitly once the
/// new one is saved.
class AvatarStore {
  AvatarStore({Future<Directory> Function()? documentsDir})
    : _store = ImageFileStore('avatar', documentsDir: documentsDir);

  final ImageFileStore _store;

  Future<Directory> directory() => _store.directory();

  Future<String> import(String sourcePath) => _store.import(sourcePath, namePrefix: 'avatar');

  Future<void> delete(Iterable<String> names) => _store.delete(names);

  /// Deletes the stored avatar — used when a full app reset (forgotten PIN)
  /// wipes the account itself.
  Future<void> clearAll() => _store.clearAll();
}
