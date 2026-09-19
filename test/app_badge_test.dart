import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_docs/core/providers/app_badge_providers.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12);
  final future = now.add(const Duration(hours: 1));
  final past = now.subtract(const Duration(hours: 1));

  HistoryItem entryWithReminder(DateTime? reminderAt) =>
      HistoryItem.voice(text: 'note', languageCode: 'en', reminderAt: reminderAt);

  test('nothing pending is a zero count', () {
    expect(pendingBadgeCount([], [], now), 0);
  });

  test('one incomplete task counts as one', () {
    final task = Task.create('Buy milk');
    expect(pendingBadgeCount([task], [], now), 1);
  });

  test('a completed one-off task does not count', () {
    final task = Task.create('Buy milk').copyWith(isDone: true);
    expect(pendingBadgeCount([task], [], now), 0);
  });

  test('a history entry with a future reminder counts as one', () {
    expect(pendingBadgeCount([], [entryWithReminder(future)], now), 1);
  });

  test('a history entry with a past reminder does not count', () {
    expect(pendingBadgeCount([], [entryWithReminder(past)], now), 0);
  });

  test('a history entry with no reminder does not count', () {
    expect(pendingBadgeCount([], [entryWithReminder(null)], now), 0);
  });

  test('a task with its own reminder is only counted once, not twice', () {
    final task = Task.create('Call back', reminderAt: future);
    expect(pendingBadgeCount([task], [], now), 1);
  });

  test('a recurring daily task not yet done today counts', () {
    final task = Task.create('Stretch', recurrence: TaskRecurrence.daily);
    expect(task.isDoneNow, isFalse);
    expect(pendingBadgeCount([task], [], now), 1);
  });

  test('a recurring daily task already done today does not count', () {
    // Task.isDoneNow checks lastCompletedDate against the real wall clock
    // (DateTime.now()), not the `now` fixture used elsewhere in this file —
    // it has to be genuinely "today" for the getter to read as done.
    final task = Task.create(
      'Stretch',
      recurrence: TaskRecurrence.daily,
    ).copyWith(lastCompletedDate: DateTime.now());
    expect(task.isDoneNow, isTrue);
    expect(pendingBadgeCount([task], [], now), 0);
  });

  test('pending tasks and active reminders add together', () {
    final tasks = [Task.create('A'), Task.create('B').copyWith(isDone: true), Task.create('C')];
    final history = [entryWithReminder(future), entryWithReminder(past), entryWithReminder(future)];
    // 2 pending tasks (A, C) + 2 active reminders = 4.
    expect(pendingBadgeCount(tasks, history, now), 4);
  });
}
