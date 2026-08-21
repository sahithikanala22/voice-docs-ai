import '../domain/task_repository.dart';
import 'task.dart';
import 'task_local_datasource.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._dataSource);

  final TaskLocalDataSource _dataSource;

  @override
  Future<List<Task>> getAll() async => _dataSource.readAll();

  @override
  Future<void> add(Task task) async {
    final tasks = _dataSource.readAll()..add(task);
    await _dataSource.writeAll(tasks);
  }

  @override
  Future<void> setDone(String id, bool isDone) async {
    final tasks = _dataSource.readAll();
    final index = tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    tasks[index] = tasks[index].copyWith(isDone: isDone);
    await _dataSource.writeAll(tasks);
  }

  @override
  Future<void> remove(String id) async {
    final tasks = _dataSource.readAll()..removeWhere((t) => t.id == id);
    await _dataSource.writeAll(tasks);
  }

  @override
  Future<void> clearCompleted() async {
    final tasks = _dataSource.readAll()..removeWhere((t) => t.isDone);
    await _dataSource.writeAll(tasks);
  }
}
