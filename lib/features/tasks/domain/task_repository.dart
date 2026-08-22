import '../data/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAll();

  Future<void> add(Task task);

  /// Marks a task done/not-done as of now. For a one-off task this just sets
  /// [Task.isDone]; for a recurring task it stamps (or clears)
  /// [Task.lastCompletedDate] instead — see [Task.isDoneNow].
  Future<void> setDone(String id, bool isDone);

  Future<void> remove(String id);

  Future<void> clearCompleted();

  Future<void> setReminder(String id, DateTime? reminderAt);
}
