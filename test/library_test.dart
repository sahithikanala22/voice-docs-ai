import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/features/library/domain/library_entry.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/tasks/data/task.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';

void main() {
  final now = DateTime(2026, 11, 12, 12);
  final voice = HistoryItem(
    id: 'recovered-cloud-123',
    sourceText: 'Project review with Ravi',
    sourceLanguageCode: 'en',
    timestamp: now,
    folderId: 'work',
  );
  final diary = DiaryEntry(
    id: 'diary',
    date: now,
    createdAt: now,
    updatedAt: now,
    title: 'Evening reflection',
    body: 'The project went well.',
  );
  final task = Task(
    id: 'task',
    title: 'Call Ravi about project',
    createdAt: now,
  );
  final entries = LibraryEntry.collect(
    history: [voice],
    journals: [diary],
    tasks: [task],
    recordings: [
      PendingRecording(
        id: '123',
        locale: 'en-US',
        createdAt: now,
        historyId: voice.id,
      ),
      PendingRecording(
        id: '456',
        locale: 'te-IN',
        createdAt: now,
        transcript: 'ప్రాజెక్టు గురించి మాట్లాడాలి',
      ),
    ],
  );
  test('collects every source without duplicating audio linked to a note', () {
    expect(entries, hasLength(4));
    expect(entries.map((e) => e.id).toSet(), hasLength(4));
    expect(
      entries.where((e) => e.kind == LibraryKind.audio).single.audio!.id,
      '456',
    );
    expect(recordingIdFor(voice), '123');
    expect(
      recordingIdFor(voice.copyWith(id: 'new', recordingId: '456')),
      '456',
    );
  });
  test(
    'search matches journal bodies, task titles and multilingual audio text',
    () {
      expect(
        const LibraryFilter(query: 'project').apply(entries, now),
        hasLength(3),
      );
      expect(
        const LibraryFilter(query: 'ravi project').apply(entries, now),
        hasLength(2),
      );
      expect(
        const LibraryFilter(
          query: 'ప్రాజెక్టు',
        ).apply(entries, now).single.kind,
        LibraryKind.audio,
      );
      expect(
        const LibraryFilter(query: 'not present').apply(entries, now),
        isEmpty,
      );
    },
  );
  test(
    'type, language and folder filters intersect rather than resetting search',
    () {
      expect(
        const LibraryFilter(
          query: 'project',
          kind: LibraryKind.task,
        ).apply(entries, now).single.task,
        task,
      );
      expect(
        const LibraryFilter(
          language: 'en',
          folderId: 'work',
        ).apply(entries, now).single.voice,
        voice,
      );
      expect(
        const LibraryFilter(folderId: '').apply(entries, now).single.audio!.id,
        '456',
      );
      expect(
        const LibraryFilter(
          kind: LibraryKind.journal,
          folderId: 'work',
        ).apply(entries, now),
        isEmpty,
      );
    },
  );
  test(
    'date ranges include the whole first day and search all entries before pagination',
    () {
      final history = List.generate(
        80,
        (i) => voice.copyWith(
          id: '$i',
          timestamp: now.subtract(Duration(days: i)),
          sourceText: i == 79 ? 'hidden needle' : 'daily note',
        ),
      );
      final all = LibraryEntry.collect(
        history: history,
        journals: [],
        tasks: [],
        recordings: [],
      );
      expect(
        const LibraryFilter(query: 'needle').apply(all, now).single.voice!.id,
        '79',
      );
      expect(
        const LibraryFilter(period: LibraryPeriod.week).apply(all, now),
        hasLength(7),
      );
      expect(
        const LibraryFilter(period: LibraryPeriod.month).apply(all, now),
        hasLength(30),
      );
    },
  );
  test('deleting the transcript makes retained audio discoverable again', () {
    final result = LibraryEntry.collect(
      history: [],
      journals: [],
      tasks: [],
      recordings: [
        PendingRecording(
          id: '123',
          locale: 'en-US',
          createdAt: now,
          historyId: voice.id,
        ),
      ],
    );
    expect(result.single.kind, LibraryKind.audio);
  });
  test('old note JSON still loads without a recording reference', () {
    final json = voice.toJson()..remove('recordingId');
    expect(HistoryItem.fromJson(json).recordingId, isNull);
    expect(
      HistoryItem.fromJson(
        voice.copyWith(recordingId: '123').toJson(),
      ).recordingId,
      '123',
    );
  });
}
