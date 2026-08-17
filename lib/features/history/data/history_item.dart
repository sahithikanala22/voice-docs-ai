import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_item.freezed.dart';
part 'history_item.g.dart';

enum HistoryItemType { voice, translation }

/// Monotonic counter appended to timestamp-based ids so two entries created
/// within the same microsecond (e.g. in a tight loop or a fast test) never
/// collide.
int _idCounter = 0;
String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// A single saved voice-to-text or translation result. Used directly across
/// data/domain/presentation — a separate "entity" would just duplicate these
/// same fields with no behavioral difference.
@freezed
class HistoryItem with _$HistoryItem {
  const factory HistoryItem({
    required String id,
    required HistoryItemType type,
    required String sourceText,
    String? translatedText,
    required String sourceLanguageCode,
    String? targetLanguageCode,
    required DateTime timestamp,
    /// Which [Folder] this entry is filed under, if any — null means
    /// unfiled. Purely organizational, set from whatever folder was
    /// "current" at save time (see `AppSettings.currentFolderId`).
    String? folderId,
  }) = _HistoryItem;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => _$HistoryItemFromJson(json);

  factory HistoryItem.voice({required String text, required String languageCode, String? folderId}) {
    return HistoryItem(
      id: _nextId(),
      type: HistoryItemType.voice,
      sourceText: text,
      sourceLanguageCode: languageCode,
      timestamp: DateTime.now(),
      folderId: folderId,
    );
  }

  factory HistoryItem.translation({
    required String sourceText,
    required String translatedText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    String? folderId,
  }) {
    return HistoryItem(
      id: _nextId(),
      type: HistoryItemType.translation,
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      timestamp: DateTime.now(),
      folderId: folderId,
    );
  }
}
