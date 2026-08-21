import '../domain/folder_repository.dart';
import 'folder.dart';
import 'folder_local_datasource.dart';

class FolderRepositoryImpl implements FolderRepository {
  FolderRepositoryImpl(this._dataSource);

  final FolderLocalDataSource _dataSource;

  @override
  Future<List<Folder>> getAll() async => _dataSource.readAll();

  @override
  Future<void> add(Folder folder) async {
    final folders = _dataSource.readAll()..add(folder);
    await _dataSource.writeAll(folders);
  }

  @override
  Future<void> update(String id, {String? name, int? colorIndex}) async {
    final folders = _dataSource.readAll();
    final index = folders.indexWhere((f) => f.id == id);
    if (index == -1) return;
    folders[index] = folders[index].copyWith(
      name: name ?? folders[index].name,
      colorIndex: colorIndex ?? folders[index].colorIndex,
    );
    await _dataSource.writeAll(folders);
  }

  @override
  Future<void> remove(String id) async {
    final folders = _dataSource.readAll()..removeWhere((f) => f.id == id);
    await _dataSource.writeAll(folders);
  }
}
