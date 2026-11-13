import '../../diary/data/diary_entry.dart';
import '../../history/data/history_item.dart';
import '../../history/domain/entry_summary.dart';
import '../../history/domain/history_search.dart';
import '../../speech_to_text/data/pending_recording_store.dart';
import '../../tasks/data/task.dart';

enum LibraryKind {
  voice('Voice notes'),
  journal('Journal'),
  task('Tasks'),
  audio('Audio');

  const LibraryKind(this.label);
  final String label;
}

enum LibraryPeriod { all, week, month }

String? recordingIdFor(HistoryItem item) {
  if (item.recordingId != null) return item.recordingId;
  final match = RegExp(r'^recovered-cloud-(\d+)$').firstMatch(item.id);
  return match?.group(1);
}

/// Search reads the existing stores; it never creates a second copy of notes.
class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    required this.date,
    this.language,
    this.folderId,
    this.voice,
    this.journal,
    this.task,
    this.audio,
  });
  final String id, title, text;
  final LibraryKind kind;
  final DateTime date;
  final String? language, folderId;
  final HistoryItem? voice;
  final DiaryEntry? journal;
  final Task? task;
  final PendingRecording? audio;

  static List<LibraryEntry> collect({
    required List<HistoryItem> history,
    required List<DiaryEntry> journals,
    required List<Task> tasks,
    required List<PendingRecording> recordings,
  }) {
    final linkedAudio = history.map(recordingIdFor).whereType<String>().toSet();
    return [
      for (final item in history)
        LibraryEntry(
          id: 'voice:${item.id}',
          kind: LibraryKind.voice,
          title: entrySummary(item.sourceText),
          text: item.sourceText,
          date: item.timestamp,
          language: item.sourceLanguageCode,
          folderId: item.folderId,
          voice: item,
        ),
      for (final item in journals)
        LibraryEntry(
          id: 'journal:${item.id}',
          kind: LibraryKind.journal,
          title: item.displayTitle,
          text: item.body,
          date: item.date,
          journal: item,
        ),
      for (final item in tasks)
        LibraryEntry(
          id: 'task:${item.id}',
          kind: LibraryKind.task,
          title: item.title,
          text: item.title,
          date: item.createdAt,
          task: item,
        ),
      for (final item in recordings.where((r) => !linkedAudio.contains(r.id)))
        LibraryEntry(
          id: 'audio:${item.id}',
          kind: LibraryKind.audio,
          title: item.transcript.trim().isEmpty
              ? 'Saved recording'
              : entrySummary(item.transcript),
          text: item.transcript,
          date: item.entryDate ?? item.createdAt,
          language: item.locale.split(RegExp('[-_]')).first,
          folderId: item.folderId,
          audio: item,
        ),
    ]..sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
  }
}

class LibraryFilter {
  const LibraryFilter({
    this.query = '',
    this.kind,
    this.period = LibraryPeriod.all,
    this.language,
    this.folderId,
  });
  final String query;
  final LibraryKind? kind;
  final LibraryPeriod period;
  final String? language;

  /// null = all folders; empty = unfiled voice/audio entries.
  final String? folderId;

  List<LibraryEntry> apply(List<LibraryEntry> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = switch (period) {
      LibraryPeriod.all => null,
      LibraryPeriod.week => DateTime(today.year, today.month, today.day - 6),
      LibraryPeriod.month => DateTime(today.year, today.month, today.day - 29),
    };
    return entries.where((entry) {
      if (kind != null && kind != entry.kind) return false;
      if (cutoff != null && entry.date.isBefore(cutoff)) return false;
      if (language != null && entry.language != language) return false;
      if (folderId != null) {
        if (entry.kind != LibraryKind.voice &&
            entry.kind != LibraryKind.audio) {
          return false;
        }
        if (folderId == ''
            ? entry.folderId != null
            : entry.folderId != folderId) {
          return false;
        }
      }
      return matchesSearch('${entry.title} ${entry.text}', query);
    }).toList();
  }
}
