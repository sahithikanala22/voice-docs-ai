import '../domain/task_repository.dart';
import 'task.dart';
import 'task_local_datasource.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._dataSource);
  final TaskLocalDataSource _dataSource;
  Future<void> _writes = Future.value();
  Future<void> _mutate(void Function(List<Task>) change) {
    final result = _writes.then((_) async {
      final tasks = await _dataSource.readAll();
      change(tasks);
      await _dataSource.writeAll(tasks);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<List<Task>> getAll() async {
    await _writes;
    return _dataSource.readAll();
  }

  @override
  Future<void> add(Task task) => _mutate((tasks) => tasks.add(task));
  @override
  Future<void> setDone(String id, bool isDone) => _mutate((tasks) {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final task = tasks[index];
    tasks[index] = task.recurrence == TaskRecurrence.none
        ? task.copyWith(isDone: isDone)
        : task.copyWith(lastCompletedDate: isDone ? DateTime.now() : null);
  });
  @override
  Future<void> remove(String id) =>
      _mutate((tasks) => tasks.removeWhere((t) => t.id == id));
  @override
  Future<void> clearCompleted() =>
      _mutate((tasks) => tasks.removeWhere((t) => t.isDone));
  @override
  Future<void> setReminder(String id, DateTime? reminderAt) => _mutate((tasks) {
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(reminderAt: reminderAt);
    }
  });
}
