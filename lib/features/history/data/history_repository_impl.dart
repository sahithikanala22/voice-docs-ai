import '../domain/history_repository.dart';
import 'history_item.dart';
import 'history_local_datasource.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._dataSource);
  final HistoryLocalDataSource _dataSource;
  Future<void> _writes = Future.value();
  Future<void> _mutate(void Function(List<HistoryItem>) change) {
    final result = _writes.then((_) async {
      final items = await _dataSource.readAll();
      change(items);
      await _dataSource.writeAll(items);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<List<HistoryItem>> getAll() async {
    await _writes;
    return _dataSource.readAll();
  }

  @override
  Future<void> add(HistoryItem item) => _mutate((items) {
    // Recording recovery reuses a stable ID, including after a crash
    // between saving history and acknowledging the recording metadata.
    if (!items.any((existing) => existing.id == item.id)) items.insert(0, item);
  });
  @override
  Future<void> remove(String id) =>
      _mutate((items) => items.removeWhere((e) => e.id == id));
  @override
  Future<void> clear() => _mutate((items) => items.clear());
  @override
  Future<void> updateFolder(String id, String? folderId) => _mutate((items) {
    final index = items.indexWhere((e) => e.id == id);
    if (index >= 0) items[index] = items[index].copyWith(folderId: folderId);
  });
  @override
  Future<void> unfileFolder(String folderId) => _mutate((items) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].folderId == folderId) {
        items[i] = items[i].copyWith(folderId: null);
      }
    }
  });
  @override
  Future<void> updateReminder(String id, DateTime? reminderAt) =>
      _mutate((items) {
        final index = items.indexWhere((e) => e.id == id);
        if (index >= 0) {
          items[index] = items[index].copyWith(reminderAt: reminderAt);
        }
      });
}
