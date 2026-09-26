import 'package:flutter/material.dart';

import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';

/// Any one of the three kinds of thing Calendar can show for a given day —
/// a voice history entry, a task with a reminder, or a diary entry — so the
/// day list can hold a single, type-safe, sortable collection instead of
/// three parallel lists.
sealed class CalendarDayItem {
  const CalendarDayItem();

  /// The day (already truncated to just year/month/day) this item belongs
  /// to — the key a caller buckets it under.
  DateTime get day;

  /// Ordering within a day's list.
  DateTime get sortTime;
}

class HistoryDayItem extends CalendarDayItem {
  const HistoryDayItem(this.item);

  final HistoryItem item;

  @override
  DateTime get day => DateUtils.dateOnly(item.timestamp);

  @override
  DateTime get sortTime => item.timestamp;
}

/// Only ever constructed for a [Task] with a non-null [Task.reminderAt] — a
/// task with no reminder has no day at all (see [Task]'s own doc comment)
/// and is correctly never shown on Calendar.
class TaskDayItem extends CalendarDayItem {
  TaskDayItem(this.task) : assert(task.reminderAt != null);

  final Task task;

  @override
  DateTime get day => DateUtils.dateOnly(task.reminderAt!);

  @override
  DateTime get sortTime => task.reminderAt!;
}

class DiaryDayItem extends CalendarDayItem {
  const DiaryDayItem(this.entry);

  final DiaryEntry entry;

  @override
  DateTime get day => DateUtils.dateOnly(entry.date);

  @override
  DateTime get sortTime => entry.date;
}
