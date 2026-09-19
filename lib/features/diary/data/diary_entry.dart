import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/diary_mood.dart';
import '../domain/diary_theme.dart';

part 'diary_entry.freezed.dart';
part 'diary_entry.g.dart';

/// Monotonic counter appended to timestamp-based ids so two entries created
/// within the same microsecond never collide — same scheme as `HistoryItem`.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// One diary page. Deliberately separate from `HistoryItem`: history is a log
/// of quick voice captures, the diary is something you sit down and compose,
/// with photos, a mood and a page theme.
@freezed
abstract class DiaryEntry with _$DiaryEntry {
  const factory DiaryEntry({
    required String id,

    /// The day the entry is *about* — pickable, so you can write up
    /// yesterday. Sorting and grouping use this, not [createdAt].
    required DateTime date,
    @Default('') String title,

    /// Plain-text mirror of [bodyDelta] — used for search and list previews,
    /// which have no reason to parse rich text just to match/snippet it. Kept
    /// in sync on every save.
    @Default('') String body,

    /// The body as a JSON-encoded Quill Delta (bold/italic/underline/etc.),
    /// null for an entry with no styling — either never written, or written
    /// before this field existed, in which case [body] is what it has and
    /// the editor starts a plain document from that.
    String? bodyDelta,

    /// File names inside the diary photo directory (see `DiaryPhotoStore`),
    /// not absolute paths — the app's storage path can change across
    /// installs and restores, the names don't.
    @Default(<String>[]) List<String> photos,

    /// Null means no mood picked. An unrecognised saved value (from a newer
    /// build) decodes to null rather than failing the whole entry.
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DiaryMood? mood,

    @JsonKey(unknownEnumValue: DiaryTheme.classic) @Default(DiaryTheme.classic) DiaryTheme theme,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DiaryEntry;

  const DiaryEntry._();

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => _$DiaryEntryFromJson(json);

  factory DiaryEntry.create({required DateTime date}) {
    final now = DateTime.now();
    return DiaryEntry(id: _nextId(), date: date, createdAt: now, updatedAt: now);
  }

  /// Nothing worth saving — used to avoid storing blank pages.
  bool get isBlank => title.trim().isEmpty && body.trim().isEmpty && photos.isEmpty;
}
