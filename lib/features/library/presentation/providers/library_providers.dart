import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';
import '../../domain/library_entry.dart';

final pendingRecordingStoreProvider = Provider<PendingRecordingStore>(
  (ref) =>
      PendingRecordingStore(PrivateStore(ref.watch(sharedPreferencesProvider))),
);

final savedRecordingsProvider = FutureProvider<List<PendingRecording>>(
  (ref) => ref.watch(pendingRecordingStoreProvider).list(),
);

class LibrarySnapshot {
  const LibrarySnapshot(
    this.entries, {
    required this.loading,
    required this.hasError,
  });
  final List<LibraryEntry> entries;
  final bool loading, hasError;
}

final libraryProvider = Provider<LibrarySnapshot>((ref) {
  final history = ref.watch(historyControllerProvider);
  final journals = ref.watch(diaryControllerProvider);
  final tasks = ref.watch(taskControllerProvider);
  final recordings = ref.watch(savedRecordingsProvider);
  return LibrarySnapshot(
    LibraryEntry.collect(
      history: history.value ?? [],
      journals: journals.value ?? [],
      tasks: tasks.value ?? [],
      recordings: recordings.value ?? [],
    ),
    loading:
        history.isLoading ||
        journals.isLoading ||
        tasks.isLoading ||
        recordings.isLoading,
    hasError:
        history.hasError ||
        journals.hasError ||
        tasks.hasError ||
        recordings.hasError,
  );
});
