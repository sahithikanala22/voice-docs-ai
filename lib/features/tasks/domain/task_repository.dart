import '../data/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAll();

  Future<void> add(Task task);

  Future<void> setDone(String id, bool isDone);

  Future<void> remove(String id);

  Future<void> clearCompleted();
}
