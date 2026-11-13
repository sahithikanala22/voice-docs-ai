import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../pending_recording_store.dart';
import '../whisper_model_store.dart';
import '../../domain/recording_phase.dart';
import '../../domain/transcript_segment.dart';
import 'durable_recording_provider.dart';

class WhisperWord {
  const WhisperWord(this.text, this.start, this.end);
  final String text;
  final Duration start, end;
}

abstract interface class OfflineWhisperTranscriber {
  Future<List<WhisperWord>> transcribe({
    required String audioPath,
    required String modelPath,
    required String language,
  });
}

/// File API only: Whisper never opens a microphone or downloads a model here.
class NativeWhisperTranscriber implements OfflineWhisperTranscriber {
  @override
  Future<List<WhisperWord>> transcribe({
    required String audioPath,
    required String modelPath,
    required String language,
  }) async {
    final result = await const Whisper(model: WhisperModel.base).transcribe(
      modelPath: modelPath,
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: language,
        isTranslate: false,
        splitOnWord: true,
        isNoTimestamps: false,
        threads: min(4, Platform.numberOfProcessors),
        noContext: true,
        maxContext: 0,
      ),
    );
    final segments = result.segments;
    if (segments == null && result.text.trim().isNotEmpty) {
      throw StateError(
        'Whisper returned no timestamps. Audio is kept for retry or export.',
      );
    }
    return [
      for (final segment in segments ?? <WhisperTranscribeSegment>[])
        WhisperWord(segment.text, segment.fromTs, segment.toTs),
    ];
  }
}

class WhisperSpeechProvider extends DurableRecordingProvider {
  WhisperSpeechProvider({
    required this.models,
    OfflineWhisperTranscriber? transcriber,
    Future<Directory> Function()? temporary,
    super.recoveryStore,
    super.recorder,
  }) : transcriber = transcriber ?? NativeWhisperTranscriber(),
       _temporary = temporary ?? getTemporaryDirectory;
  final WhisperModelStore models;
  final OfflineWhisperTranscriber transcriber;
  final Future<Directory> Function() _temporary;
  static const backend = 'whisperBase30v1';
  static const bytesPerSecond = 32000,
      chunkBytes = 30 * bytesPerSecond,
      overlapBytes = 2 * bytesPerSecond;
  static bool _nativeJobActive = false;

  /// Remove only app-owned scratch jobs, never durable capture/model files.
  /// Called at startup and when explicitly deleting a recovered recording.
  static Future<void> cleanupScratch(
    Directory temporary, {
    String? recordingId,
  }) async {
    if (_nativeJobActive) return;
    if (recordingId != null && !RegExp(r'^\d+$').hasMatch(recordingId)) {
      throw const FormatException('Invalid recording ID');
    }
    final parent = Directory('${temporary.path}/voicedocsai_whisper_jobs');
    if (await FileSystemEntity.type(parent.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    await for (final entity in parent.list(followLinks: false)) {
      final name = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (entity is Directory &&
          RegExp(r'^\d+_').hasMatch(name) &&
          (recordingId == null || name.startsWith('${recordingId}_'))) {
        await entity.delete(recursive: true);
      }
    }
  }

  static String languageFor(String locale) {
    final primary = locale.toLowerCase().replaceAll('_', '-').split('-').first;
    if (primary == 'und' || primary.isEmpty) {
      throw StateError(
        'Choose the original recording language before retrying.',
      );
    }
    return primary;
  }

  @override
  Future<String> transcribeRetained(
    PendingRecording recording, {
    bool resetCancellation = true,
  }) async {
    final store = await recovery;
    if (_nativeJobActive || !await store.acquireJob(recording.id)) {
      throw StateError('Another transcription is finishing. Wait, then retry.');
    }
    // Recheck after acquiring the asynchronous per-recording lease.
    if (_nativeJobActive) {
      await store.releaseJob(recording.id);
      throw StateError('Another offline transcription is finishing.');
    }
    _nativeJobActive = true;
    if (resetCancellation) cancellation = CancelToken();
    final token = cancellation;
    Directory? scratch;
    void checkCancelled() {
      if (token.isCancelled) throw token.cancelError!;
    }

    try {
      checkCancelled();
      final model = await models.requireReady();
      checkCancelled();
      await store.selectTranscriptionBackend(recording.id, backend);
      var item = await store.get(recording.id);
      final language = languageFor(item.locale);
      if (item.byteLength == 0) {
        throw StateError('No captured audio is available.');
      }
      if (item.phase == RecordingPhase.completed &&
          item.transcript.isNotEmpty) {
        return item.transcript;
      }
      await store.sealCapture(item.id);
      await store.setPhase(item.id, RecordingPhase.transcribing);
      emitProgress(RecordingPhase.transcribing, saved: true, id: item.id);
      scratch = await Directory(
        '${(await _temporary()).path}/voicedocsai_whisper_jobs',
      ).create(recursive: true);
      scratch = await scratch.createTemp('${item.id}_');
      final count = (item.byteLength / chunkBytes).ceil();
      for (var index = 0; index < count; index++) {
        checkCancelled();
        if (item.chunks.containsKey(index) && item.chunks[index]!.isNotEmpty) {
          continue;
        }
        final coreStart = index * chunkBytes;
        final coreEnd = min(coreStart + chunkBytes, item.byteLength);
        final start = max(0, coreStart - overlapBytes);
        final end = min(item.byteLength, coreEnd + overlapBytes);
        final wav = await store.exportWav(
          item.id,
          scratch,
          offset: start,
          length: end - start,
          filename: 'chunk.wav',
        );
        checkCancelled();
        final words = await transcriber.transcribe(
          audioPath: wav.path,
          modelPath: model,
          language: language,
        );
        // Native file inference cannot be aborted by this plugin. Ignore its
        // result after cancellation and do not start any subsequent chunk.
        checkCancelled();
        final selected = words.where((word) {
          final middle =
              start / bytesPerSecond +
              (word.start.inMicroseconds + word.end.inMicroseconds) / 2000000;
          return middle >= coreStart / bytesPerSecond &&
              middle < coreEnd / bytesPerSecond;
        }).toList();
        final text = selected
            .map((word) => word.text.trim())
            .where((text) => text.isNotEmpty)
            .join(' ');
        final origin = Duration(
          microseconds: start * 1000000 ~/ bytesPerSecond,
        );
        await store.saveChunk(
          item.id,
          index,
          text,
          segments: [
            for (final word in selected)
              if (word.text.trim().isNotEmpty &&
                  word.start >= Duration.zero &&
                  word.end >= word.start)
                TranscriptSegment(
                  text: word.text.trim(),
                  start: origin + word.start,
                  end: origin + word.end > item.duration
                      ? item.duration
                      : origin + word.end,
                ),
          ],
        );
        item = await store.get(item.id);
      }
      checkCancelled();
      if (item.transcript.trim().isEmpty) {
        throw StateError(
          'No speech was recognized. Original audio is kept for playback, export or retry.',
        );
      }
      await store.saveTranscript(item.id, item.transcript);
      emitProgress(RecordingPhase.completed, saved: true, id: item.id);
      return item.transcript;
    } catch (error) {
      final phase = token.isCancelled
          ? RecordingPhase.interrupted
          : RecordingPhase.failed;
      try {
        await store.setPhase(
          recording.id,
          phase,
          error: error is StateError
              ? error.message.toString()
              : transcriptionFailureMessage,
        );
      } catch (_) {
        /* Keep unreadable files untouched. */
      }
      emitProgress(phase, saved: true, id: recording.id);
      rethrow;
    } finally {
      try {
        if (scratch != null && await scratch.exists()) {
          await scratch.delete(recursive: true);
        }
      } finally {
        _nativeJobActive = false;
        await store.releaseJob(recording.id);
      }
    }
  }
}
