import 'package:flutter_local_notifications/flutter_local_notifications.dart' show DateTimeComponents;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/services/notification_service.dart';

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

  Future<void> addTask(
    String title, {
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? reminderAt,
  }) async {
    final task = Task.create(title, recurrence: recurrence, reminderAt: reminderAt);
    await ref.read(taskRepositoryProvider).add(task);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
    if (reminderAt != null) await _scheduleReminder(task);
  }

  Future<void> setDone(String id, bool isDone) async {
    await ref.read(taskRepositoryProvider).setDone(id, isDone);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
  }

  Future<void> removeTask(String id) async {
    await ref.read(taskRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
    await ref.read(notificationServiceProvider).cancel(reminderNotificationId(id));
  }

  Future<void> clearCompleted() async {
    final completedIds = (state.value ?? const []).where((t) => t.isDone).map((t) => t.id).toList();
    await ref.read(taskRepositoryProvider).clearCompleted();
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
    for (final id in completedIds) {
      await ref.read(notificationServiceProvider).cancel(reminderNotificationId(id));
    }
  }

  /// Sets, replaces, or clears (pass null) the reminder on an already-saved
  /// task.
  Future<void> setReminder(String id, DateTime? reminderAt) async {
    await ref.read(taskRepositoryProvider).setReminder(id, reminderAt);
    state = AsyncData(await ref.read(taskRepositoryProvider).getAll());
    final notificationId = reminderNotificationId(id);
    if (reminderAt == null) {
      await ref.read(notificationServiceProvider).cancel(notificationId);
      return;
    }
    final task = state.value?.where((t) => t.id == id).firstOrNull;
    if (task != null) await _scheduleReminder(task);
  }

  Future<void> _scheduleReminder(Task task) async {
    final reminderAt = task.reminderAt;
    if (reminderAt == null) return;
    // A one-off reminder in the past is pointless; a recurring one isn't —
    // the plugin schedules the next matching occurrence regardless of
    // whether the anchor moment itself has already passed.
    if (task.recurrence == TaskRecurrence.none && !reminderAt.isAfter(DateTime.now())) return;

    final notificationService = ref.read(notificationServiceProvider);
    final granted = await notificationService.requestPermission();
    if (!granted) return;

    final matchComponents = switch (task.recurrence) {
      TaskRecurrence.none => null,
      TaskRecurrence.daily => DateTimeComponents.time,
      TaskRecurrence.weekly => DateTimeComponents.dayOfWeekAndTime,
    };
    await notificationService.scheduleReminder(
      id: reminderNotificationId(task.id),
      title: 'Task reminder',
      body: task.title,
      scheduledDate: reminderAt,
      matchDateTimeComponents: matchComponents,
    );
  }
}
