import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// Monotonic counter appended to timestamp-based ids so two tasks created
/// within the same microsecond never collide — same scheme as `HistoryItem`
/// and `Folder`.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

enum TaskRecurrence { none, daily, weekly }

/// A single to-do item on the Tasks tab's checklist — deliberately date-less
/// as far as *completion* goes: it's a running list you clear as you go, not
/// something scheduled for a specific day (that's what a Calendar entry
/// with a reminder is for). It can still carry its own [reminderAt]
/// notification, independent of that distinction.
///
/// A one-off task ([TaskRecurrence.none]) uses [isDone] like a normal
/// checklist item: check it, it stays checked until you clear it. A
/// recurring task instead uses [lastCompletedDate] — checking it off just
/// records "done as of X", so it naturally shows unchecked again once a new
/// day (or week) starts, without ever being deleted. See [Task.isDoneNow].
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required DateTime createdAt,
    @Default(false) bool isDone,
    @Default(TaskRecurrence.none) TaskRecurrence recurrence,
    DateTime? lastCompletedDate,
    /// When set, a local notification is scheduled for this moment — see
    /// `NotificationService.scheduleReminder`. For a recurring task this is
    /// the anchor whose time-of-day (daily) or weekday+time (weekly) the
    /// repeating notification is based on, not a one-off date. Null means
    /// no reminder.
    DateTime? reminderAt,
  }) = _Task;

  const Task._();

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  factory Task.create(String title, {TaskRecurrence recurrence = TaskRecurrence.none, DateTime? reminderAt}) =>
      Task(
        id: _nextId(),
        title: title,
        createdAt: DateTime.now(),
        recurrence: recurrence,
        reminderAt: reminderAt,
      );

  /// Whether this task should currently render as checked. For a one-off
  /// task that's just [isDone]; for a recurring task it's whether
  /// [lastCompletedDate] falls within the current period (today for daily,
  /// the last 7 days for weekly).
  bool get isDoneNow {
    if (recurrence == TaskRecurrence.none) return isDone;
    final last = lastCompletedDate;
    if (last == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDay = DateUtils.dateOnly(last);
    return switch (recurrence) {
      TaskRecurrence.daily => DateUtils.isSameDay(lastDay, today),
      TaskRecurrence.weekly => !lastDay.isBefore(today.subtract(const Duration(days: 6))),
      TaskRecurrence.none => isDone,
    };
  }
}
