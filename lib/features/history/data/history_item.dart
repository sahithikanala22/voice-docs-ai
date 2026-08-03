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
  }) = _HistoryItem;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => _$HistoryItemFromJson(json);

  factory HistoryItem.voice({required String text, required String languageCode}) {
    return HistoryItem(
      id: _nextId(),
      type: HistoryItemType.voice,
      sourceText: text,
      sourceLanguageCode: languageCode,
      timestamp: DateTime.now(),
    );
  }

  factory HistoryItem.translation({
    required String sourceText,
    required String translatedText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) {
    return HistoryItem(
      id: _nextId(),
      type: HistoryItemType.translation,
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      timestamp: DateTime.now(),
    );
  }
}
