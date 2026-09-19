import '../domain/diary_repository.dart';
import 'diary_entry.dart';
import 'diary_local_datasource.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  DiaryRepositoryImpl(this._dataSource);

  final DiaryLocalDataSource _dataSource;

  @override
  Future<List<DiaryEntry>> getAll() async => _dataSource.readAll();

  @override
  Future<void> save(DiaryEntry entry) async {
    final entries = _dataSource.readAll();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    await _dataSource.writeAll(entries);
  }

  @override
  Future<void> remove(String id) async {
    final entries = _dataSource.readAll()..removeWhere((e) => e.id == id);
    await _dataSource.writeAll(entries);
  }
}
