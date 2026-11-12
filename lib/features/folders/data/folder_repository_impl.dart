import '../domain/folder_repository.dart';
import 'folder.dart';
import 'folder_local_datasource.dart';

class FolderRepositoryImpl implements FolderRepository {
  FolderRepositoryImpl(this._dataSource);
  final FolderLocalDataSource _dataSource;
  Future<void> _writes = Future.value();
  Future<void> _mutate(void Function(List<Folder>) change) {
    final result = _writes.then((_) async {
      final folders = await _dataSource.readAll();
      change(folders);
      await _dataSource.writeAll(folders);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<List<Folder>> getAll() async {
    await _writes;
    return _dataSource.readAll();
  }

  @override
  Future<void> add(Folder folder) => _mutate((folders) => folders.add(folder));
  @override
  Future<void> update(String id, {String? name, int? colorIndex}) =>
      _mutate((folders) {
        final index = folders.indexWhere((f) => f.id == id);
        if (index == -1) return;
        folders[index] = folders[index].copyWith(
          name: name ?? folders[index].name,
          colorIndex: colorIndex ?? folders[index].colorIndex,
        );
      });
  @override
  Future<void> remove(String id) =>
      _mutate((folders) => folders.removeWhere((f) => f.id == id));
}
