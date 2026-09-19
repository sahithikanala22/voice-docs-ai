import '../data/diary_entry.dart';

abstract class DiaryRepository {
  Future<List<DiaryEntry>> getAll();

  /// Inserts [entry], or replaces the existing entry with the same id.
  Future<void> save(DiaryEntry entry);

  Future<void> remove(String id);
}
