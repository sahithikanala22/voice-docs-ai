import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/task.dart';
import '../../data/task_local_datasource.dart';
import '../../data/task_repository_impl.dart';
import '../../domain/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TaskRepositoryImpl(TaskLocalDataSource(prefs));
});

/// Holds the full task checklist and exposes mutation methods that
/// immediately persist and refresh state — the UI never talks to the
/// repository directly.
final taskControllerProvider = AsyncNotifierProvider<TaskController, List<Task>>(TaskController.new);

class TaskController extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    return ref.watch(taskRepositoryProvider).getAll();
  }

  Future<void> addTask(String title) async {
    await ref.read(taskRepositoryProvider).add(Task.create(title));
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
  }

  Future<void> setDone(String id, bool isDone) async {
    await ref.read(taskRepositoryProvider).setDone(id, isDone);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
  }

  Future<void> removeTask(String id) async {
    await ref.read(taskRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
  }

  Future<void> clearCompleted() async {
    await ref.read(taskRepositoryProvider).clearCompleted();
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
  }
}
