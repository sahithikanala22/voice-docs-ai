import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// Monotonic counter appended to timestamp-based ids so two tasks created
/// within the same microsecond never collide — same scheme as `HistoryItem`
/// and `Folder`.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// A single to-do item on the Voice tab's "Today's tasks" checklist —
/// deliberately date-less: it's a running list you clear as you go, not
/// something scheduled for a specific day (that's what a Calendar entry
/// with a reminder is for).
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required DateTime createdAt,
    @Default(false) bool isDone,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  factory Task.create(String title) => Task(id: _nextId(), title: title, createdAt: DateTime.now());
}
