import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Owns a set of image files copied into their own subdirectory of the app's
/// private documents storage.
///
/// A picked image is *copied* in rather than referenced where it was picked
/// from, so it survives even if later deleted from the gallery, and the
/// cached copy the picker hands back (which the OS is free to clear at any
/// time) never matters again. Every saved name gets a fresh timestamp rather
/// than reusing one, which sidesteps `Image.file`'s path-based caching: a
/// replaced photo at the *same* file name can otherwise still show the old
/// bytes.
///
/// Shared by [DiaryPhotoStore] and the profile avatar — same file lifecycle
/// (import, delete, wipe-everything-on-reset), different subdirectory.
class ImageFileStore {
  ImageFileStore(this._subdirectory, {Future<Directory> Function()? documentsDir})
    : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final String _subdirectory;
  final Future<Directory> Function() _documentsDir;
  Directory? _dir;

  Future<Directory> directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    final dir = Directory('${(await _documentsDir()).path}/$_subdirectory');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Copies the file at [sourcePath] into the store and returns the new
  /// file's name, which is what a caller keeps a reference to.
  Future<String> import(String sourcePath, {String namePrefix = 'file'}) async {
    final dir = await directory();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot == -1 ? '.jpg' : sourcePath.substring(dot).toLowerCase();
    final name = '${namePrefix}_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(sourcePath).copy('${dir.path}/$name');
    return name;
  }

  /// Deletes the named files. Missing ones are ignored — after a restore on
  /// a new phone a reference can point at a file that was never copied over.
  Future<void> delete(Iterable<String> names) async {
    final dir = await directory();
    for (final name in names) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }

  /// Deletes everything in the store — used when a full app reset wipes
  /// whatever referenced these files, so they don't linger as orphans with
  /// nothing left pointing at them.
  Future<void> clearAll() async {
    final dir = await directory();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
  }
}
