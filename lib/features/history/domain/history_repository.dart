import '../data/history_item.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getAll();

  Future<void> add(HistoryItem item);

  Future<void> remove(String id);

  Future<void> clear();

  Future<void> updateFolder(String id, String? folderId);

  Future<void> updateReminder(String id, DateTime? reminderAt);
}
