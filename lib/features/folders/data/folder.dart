import 'package:freezed_annotation/freezed_annotation.dart';

part 'folder.freezed.dart';
part 'folder.g.dart';

/// Monotonic counter appended to timestamp-based ids so two folders created
/// within the same microsecond never collide — same scheme as `HistoryItem`.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// A user-named container for organizing history entries (e.g. "Diary",
/// "Work"). Purely organizational — deleting a folder never deletes the
/// entries in it, they just become unfiled again.
@freezed
class Folder with _$Folder {
  const factory Folder({
    required String id,
    required String name,
    required DateTime createdAt,
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);

  factory Folder.create(String name) => Folder(id: _nextId(), name: name, createdAt: DateTime.now());
}
