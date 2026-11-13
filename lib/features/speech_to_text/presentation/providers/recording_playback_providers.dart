import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/library/presentation/providers/library_providers.dart';
import '../../data/pending_recording_store.dart';
import '../../data/recording_playback_controller.dart';
import '../../domain/transcript_segment.dart';

final recordingPlaybackProvider =
    ChangeNotifierProvider<RecordingPlaybackController>(
      (ref) =>
          RecordingPlaybackController(ref.watch(pendingRecordingStoreProvider)),
    );

final retainedRecordingProvider = FutureProvider.autoDispose
    .family<PendingRecording, String>(
      (ref, id) => ref.watch(pendingRecordingStoreProvider).get(id),
    );

final playbackPassagesProvider = Provider.autoDispose
    .family<List<TranscriptSegment>, String>((ref, id) {
      final segments = ref.watch(
        retainedRecordingProvider(id).select((value) => value.value?.segments),
      );
      return transcriptPassages(segments ?? []);
    });
