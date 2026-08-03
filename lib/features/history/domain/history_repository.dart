import '../data/history_item.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getAll();

  Future<void> add(HistoryItem item);

  Future<void> remove(String id);

  Future<void> clear();
}
