import 'package:voxi_translate/core/constants/app_constants.dart';

import '../domain/history_repository.dart';
import 'history_item.dart';
import 'history_local_datasource.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._dataSource);

  final HistoryLocalDataSource _dataSource;

  @override
  Future<List<HistoryItem>> getAll() async => _dataSource.readAll();

  @override
  Future<void> add(HistoryItem item) async {
    final items = _dataSource.readAll()..insert(0, item);
    final trimmed = items.length > AppConstants.maxHistoryItems
        ? items.sublist(0, AppConstants.maxHistoryItems)
        : items;
    await _dataSource.writeAll(trimmed);
  }

  @override
  Future<void> remove(String id) async {
    final items = _dataSource.readAll()..removeWhere((e) => e.id == id);
    await _dataSource.writeAll(items);
  }

  @override
  Future<void> clear() async => _dataSource.writeAll([]);
}
