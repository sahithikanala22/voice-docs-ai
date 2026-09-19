import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/services/app_badge_service.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';

/// Tasks not yet done, plus history entries with a reminder still in the
/// future — what the launcher badge should currently read. A task's own
/// reminder isn't counted separately: it's already represented by the task
/// being incomplete, and counting both would double-count the same thing
/// you added. Pulled out from [appBadgeWatcherProvider] as a plain function
/// so the count itself is testable without a working badge plugin.
int pendingBadgeCount(List<Task> tasks, List<HistoryItem> history, DateTime now) {
  final pendingTasks = tasks.where((t) => !t.isDoneNow).length;
  final activeReminders = history
      .where((item) => item.reminderAt != null && item.reminderAt!.isAfter(now))
      .length;
  return pendingTasks + activeReminders;
}

/// Keeps the launcher icon's badge count in sync with [pendingBadgeCount].
///
/// Watched once from the app root, so it's wired up as soon as the app is
/// and reacts to either list changing — add a task, the badge appears right
/// away; complete it, the badge drops. That's the point of this provider:
/// `NotificationService`'s channel badge only shows once a reminder's
/// notification has actually fired at its scheduled time, which is a
/// separate, later moment from adding it.
final appBadgeWatcherProvider = Provider<void>((ref) {
  void refresh() {
    final tasks = ref.read(taskControllerProvider).value ?? const [];
    final history = ref.read(historyControllerProvider).value ?? const [];
    AppBadgeService.instance.setCount(pendingBadgeCount(tasks, history, DateTime.now()));
  }

  ref.listen(taskControllerProvider, (_, _) => refresh());
  ref.listen(historyControllerProvider, (_, _) => refresh());
  refresh();
});
