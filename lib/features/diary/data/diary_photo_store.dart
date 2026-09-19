import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Owns the files behind diary photos.
///
/// A picked image is *copied* into the app's private documents directory
/// rather than referenced where it was picked from, so a photo stays in the
/// diary even if it's later deleted from the gallery, and the cached copy the
/// picker hands back (which Android is free to clear) never matters.
class DiaryPhotoStore {
  DiaryPhotoStore({Future<Directory> Function()? documentsDir})
    : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;
  Directory? _dir;

  Future<Directory> directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    final dir = Directory('${(await _documentsDir()).path}/diary_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Copies the file at [sourcePath] into the store and returns the new
  /// file's name, which is what an entry keeps.
  Future<String> import(String sourcePath) async {
    final dir = await directory();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot == -1 ? '.jpg' : sourcePath.substring(dot).toLowerCase();
    final name = 'photo_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy('${dir.path}/$name');
    return name;
  }

  /// Deletes the named photos. Missing files are ignored — after a restore on
  /// a new phone an entry can reference photos that were never copied over.
  Future<void> delete(Iterable<String> names) async {
    final dir = await directory();
    for (final name in names) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }

  /// Deletes every stored photo — used when a full app reset (forgotten PIN)
  /// wipes the diary entries themselves, so their photos don't linger as
  /// orphaned files with nothing left to reference them.
  Future<void> clearAll() async {
    final dir = await directory();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
  }
}
