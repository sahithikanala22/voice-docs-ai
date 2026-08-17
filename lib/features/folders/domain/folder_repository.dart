import '../data/folder.dart';

abstract class FolderRepository {
  Future<List<Folder>> getAll();

  Future<void> add(Folder folder);

  Future<void> rename(String id, String newName);

  Future<void> remove(String id);
}
