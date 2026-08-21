import '../data/folder.dart';

abstract class FolderRepository {
  Future<List<Folder>> getAll();

  Future<void> add(Folder folder);

  /// Updates whichever of [name]/[colorIndex] is passed, leaving the other
  /// unchanged — lets the rename dialog update both in one call.
  Future<void> update(String id, {String? name, int? colorIndex});

  Future<void> remove(String id);
}
