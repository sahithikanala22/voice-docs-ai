import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'durable_recording_provider.dart';
import '../../domain/transcript_segment.dart';
import '../pending_recording_store.dart';
import '../../domain/recording_phase.dart';

class GoogleCloudSpeechProvider extends DurableRecordingProvider {
  GoogleCloudSpeechProvider({
    required this.apiKey,
    Dio? dio,
    super.recoveryStore,
    super.recorder,
    super.transcribeOnStop,
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 45),
             ),
           );
  final String apiKey;
  final Dio _dio;
  final Future<void> Function(Duration) _delay;
  static const bytesPerSecond = 32000;
  static const chunkBytes = 50 * bytesPerSecond;
  static const overlapBytes = 2 * bytesPerSecond;
  @override
  Future<void> validateStart() async {
    if (transcribeOnStop && apiKey.trim().isEmpty) {
      throw StateError(
        'Add a Google Cloud API key in Settings, or use Record meeting to save audio offline.',
      );
    }
  }

  @override
  String get transcriptionFailureMessage =>
      'Transcription failed. Audio is kept in Recover recordings. Check your connection, API key and device storage.';
  @override
  Future<String> transcribeRetained(
    PendingRecording recording, {
    bool resetCancellation = true,
  }) async {
    final store = await recovery;
    if (!await store.acquireJob(recording.id)) {
      throw StateError('This recording is already being transcribed.');
    }
    if (resetCancellation) cancellation = CancelToken();
    final token = cancellation;
    try {
      await store.selectTranscriptionBackend(recording.id, 'googleCloud');
      var item = await store.get(
        recording.id,
      ); // Locale and ID always come from durable metadata.
      if (item.phase == RecordingPhase.completed &&
          item.transcript.isNotEmpty) {
        return item.transcript;
      }
      if (apiKey.trim().isEmpty) {
        throw StateError(
          'Add a Google Cloud API key in Settings before retrying.',
        );
      }
      if (item.locale == 'und') {
        throw StateError(
          'Select the original recording language before retrying.',
        );
      }
      if (item.byteLength == 0) {
        throw StateError('No audio bytes are available for transcription.');
      }
      await store.sealCapture(item.id);
      await store.setPhase(item.id, RecordingPhase.transcribing);
      emitProgress(RecordingPhase.transcribing, saved: true);
      final count = (item.byteLength / chunkBytes).ceil();
      for (var index = 0; index < count; index++) {
        _checkCancelled(token);
        if (item.chunks.containsKey(index) &&
            !(resetCancellation && item.chunks[index]!.isEmpty)) {
          continue;
        }
        final coreStart = index * chunkBytes;
        final coreEnd = min(coreStart + chunkBytes, item.byteLength);
        final start = max(0, coreStart - overlapBytes);
        final end = min(item.byteLength, coreEnd + overlapBytes);
        final bytes = await store.readAudio(item.id, start, end - start);
        final data = await _recognizeWithRetry(bytes, item.locale, token);
        _checkCancelled(token);
        final text = extractChunk(
          data,
          requestStart: start / bytesPerSecond,
          coreStart: coreStart / bytesPerSecond,
          coreEnd: coreEnd / bytesPerSecond,
          previous: item.transcript,
          segment: index + 1,
        );
        await store.saveChunk(
          item.id,
          index,
          text,
          segments: extractSegments(
            data,
            requestStart: start / bytesPerSecond,
            coreStart: coreStart / bytesPerSecond,
            coreEnd: coreEnd / bytesPerSecond,
          ),
        );
        item = await store.get(item.id);
      }
      if (item.transcript.trim().isEmpty) {
        throw StateError(
          'No speech was recognized. Audio is kept in Recover recordings for playback or export.',
        );
      }
      await store.saveTranscript(item.id, item.transcript);
      emitProgress(RecordingPhase.completed, saved: true);
      return item.transcript;
    } catch (error) {
      try {
        await store.setPhase(
          recording.id,
          token.isCancelled
              ? RecordingPhase.interrupted
              : RecordingPhase.failed,
          error: error is StateError
              ? error.message.toString()
              : 'Transcription failed; completed chunks and audio are kept.',
        );
      } catch (_) {}
      rethrow;
    } finally {
      await store.releaseJob(recording.id);
    }
  }

  void _checkCancelled(CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
  }

  Future<Map<String, dynamic>> _recognizeWithRetry(
    Uint8List bytes,
    String locale,
    CancelToken token,
  ) async {
    for (var attempt = 0; ; attempt++) {
      _checkCancelled(token);
      try {
        try {
          return await _recognize(bytes, locale, token, enhanced: true);
        } on DioException catch (error) {
          if (error.response?.statusCode != 400) rethrow;
          return await _recognize(bytes, locale, token, enhanced: false);
        }
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final transient =
            {408, 429, 500, 502, 503, 504}.contains(status) ||
            {
              DioExceptionType.connectionError,
              DioExceptionType.connectionTimeout,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(error.type);
        if (!transient || attempt >= 2 || token.isCancelled) rethrow;
        await Future.any([
          _delay(Duration(milliseconds: 500 * (1 << attempt))),
          token.whenCancel,
        ]);
      }
    }
  }

  Future<Map<String, dynamic>> _recognize(
    Uint8List bytes,
    String locale,
    CancelToken token, {
    required bool enhanced,
  }) async {
    final config = <String, dynamic>{
      'encoding': 'LINEAR16',
      'sampleRateHertz': 16000,
      'languageCode': locale,
      'enableAutomaticPunctuation': true,
      'enableWordTimeOffsets': true,
    };
    if (enhanced) {
      config['model'] = 'latest_long';
      config['diarizationConfig'] = {
        'enableSpeakerDiarization': true,
        'minSpeakerCount': 1,
        'maxSpeakerCount': 6,
      };
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'https://speech.googleapis.com/v1/speech:recognize',
      cancelToken: token,
      queryParameters: {'key': apiKey},
      data: {
        'config': config,
        'audio': {'content': base64Encode(bytes)},
      },
    );
    return response.data ?? const {};
  }

  /// Overlap gives boundary words context. Timed words belong to exactly one
  /// core interval by midpoint. Services omitting times use conservative text
  /// overlap matching; boundary fidelity then needs review against the audio.
  static List<TranscriptSegment> extractSegments(
    Map<String, dynamic> data, {
    required double requestStart,
    required double coreStart,
    required double coreEnd,
  }) {
    final alternatives = ((data['results'] as List?) ?? [])
        .expand((r) => ((r as Map)['alternatives'] as List? ?? []).take(1))
        .cast<Map>()
        .toList();
    var words = alternatives
        .expand((a) => (a['words'] as List? ?? []))
        .cast<Map>()
        .toList();
    final lastWords = alternatives.lastOrNull?['words'] as List?;
    if (lastWords != null &&
        lastWords.any((w) => (w as Map)['speakerTag'] != null)) {
      words = lastWords.cast<Map>();
    }
    final segments = <TranscriptSegment>[];
    for (final word in words) {
      final start = double.tryParse(
        '${word['startTime']}'.replaceFirst('s', ''),
      );
      final end = double.tryParse('${word['endTime']}'.replaceFirst('s', ''));
      if (start == null ||
          end == null ||
          !start.isFinite ||
          !end.isFinite ||
          start < 0 ||
          end < start) {
        continue;
      }
      final middle = requestStart + (start + end) / 2;
      final text = word['word'] as String? ?? '';
      if (middle < coreStart || middle >= coreEnd || text.trim().isEmpty) {
        continue;
      }
      segments.add(
        TranscriptSegment(
          text: text,
          start: Duration(
            microseconds: ((requestStart + start) * 1000000).round(),
          ),
          end: Duration(microseconds: ((requestStart + end) * 1000000).round()),
        ),
      );
    }
    return segments;
  }

  static String extractChunk(
    Map<String, dynamic> data, {
    required double requestStart,
    required double coreStart,
    required double coreEnd,
    String previous = '',
    int segment = 1,
  }) {
    final results = (data['results'] as List?) ?? [];
    final alternatives = results
        .map((r) => ((r as Map)['alternatives'] as List?) ?? [])
        .where((a) => a.isNotEmpty)
        .map((a) => a.first as Map)
        .toList();
    if (alternatives.isEmpty) return '';
    var words = alternatives
        .expand((a) => (a['words'] as List?) ?? [])
        .cast<Map>()
        .toList();
    final lastWords = alternatives.last['words'] as List?;
    if (lastWords != null &&
        lastWords.any((w) => (w as Map)['speakerTag'] != null)) {
      words = lastWords
          .cast<Map>(); // Diarization's final result repeats all timed words.
    }
    double seconds(Object? value) =>
        double.tryParse(value.toString().replaceFirst('s', '')) ?? 0;
    if (words.isNotEmpty &&
        words.every((w) => w['startTime'] != null && w['endTime'] != null)) {
      final selected = words.where((w) {
        final midpoint =
            requestStart +
            (seconds(w['startTime']) + seconds(w['endTime'])) / 2;
        return midpoint >= coreStart && midpoint < coreEnd;
      }).toList();
      final speakers = selected
          .map((w) => w['speakerTag'])
          .whereType<int>()
          .toSet();
      if (speakers.length > 1) {
        final output = StringBuffer();
        int? previousSpeaker;
        for (final word in selected) {
          final speaker = word['speakerTag'] as int? ?? 1;
          if (speaker != previousSpeaker) {
            if (output.isNotEmpty) output.write('\n');
            output.write('Segment $segment, Speaker $speaker:');
            previousSpeaker = speaker;
          }
          output.write(' ${word['word'] as String? ?? ''}');
        }
        return output.toString();
      }
      return selected
          .map((w) => w['word'] as String? ?? '')
          .where((w) => w.isNotEmpty)
          .join(' ');
    }
    final text = alternatives
        .map((a) => a['transcript'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (previous.isEmpty || coreStart == 0) return text;
    final old = previous.split(RegExp(r'\s+'));
    final next = text.split(RegExp(r'\s+'));
    for (var n = min(32, min(old.length, next.length)); n > 0; n--) {
      if (old.sublist(old.length - n).join(' ').toLowerCase() ==
          next.take(n).join(' ').toLowerCase()) {
        return next.skip(n).join(' ');
      }
    }
    return text;
  }
}
