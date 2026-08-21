import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_item.freezed.dart';
part 'history_item.g.dart';

/// Monotonic counter appended to timestamp-based ids so two entries created
/// within the same microsecond (e.g. in a tight loop or a fast test) never
/// collide.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// A single saved voice-to-text entry. Used directly across
/// data/domain/presentation — a separate "entity" would just duplicate these
/// same fields with no behavioral difference.
@freezed
class HistoryItem with _$HistoryItem {
  const factory HistoryItem({
    required String id,
    required String sourceText,
    required String sourceLanguageCode,
    required DateTime timestamp,
    /// Which [Folder] this entry is filed under, if any — null means
    /// unfiled. Purely organizational, set from whatever folder was
    /// "current" at save time (see `AppSettings.currentFolderId`).
    String? folderId,
    /// When set, a local notification is scheduled for this moment — see
    /// `NotificationService.scheduleReminder`. Null means no reminder.
    DateTime? reminderAt,
  }) = _HistoryItem;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => _$HistoryItemFromJson(json);

  /// [timestamp] defaults to now — pass an explicit one for manually
  /// backfilled entries (see the Calendar tab's "Add entry" sheet), which
  /// need to land on whatever past date the user picked rather than today.
  factory HistoryItem.voice({
    required String text,
    required String languageCode,
    String? folderId,
    DateTime? timestamp,
    DateTime? reminderAt,
  }) {
    return HistoryItem(
      id: _nextId(),
      sourceText: text,
      sourceLanguageCode: languageCode,
      timestamp: timestamp ?? DateTime.now(),
      folderId: folderId,
      reminderAt: reminderAt,
    );
  }
}
