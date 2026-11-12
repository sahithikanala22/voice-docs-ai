import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/google_cloud_speech_provider.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/repositories/speech_repository_impl.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_phase.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recognition_state.dart';
import 'package:ai_voice_docs/features/history/data/history_repository_impl.dart';
import 'package:ai_voice_docs/features/history/data/history_local_datasource.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'support/fakes.dart';

class SealingFailureStore extends PrivateStore {
  SealingFailureStore(super.prefs);
  bool failWrites = false;
  @override
  Future<String> seal(String value) async {
    if (failWrites) throw const FileSystemException('No space left');
    return super.seal(value);
  }
}

class RecordingPhaseFailureStore extends PendingRecordingStore {
  RecordingPhaseFailureStore(super.store, {super.directory});
  @override
  Future<void> setPhase(String id, RecordingPhase phase, {String? error}) {
    if (phase == RecordingPhase.recording) {
      throw const FileSystemException('Metadata write failed after mic start');
    }
    return super.setPhase(id, phase, error: error);
  }
}

class RecorderFake implements AudioRecorder {
  String? path;
  final states = StreamController<RecordState>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  bool failStartAfterWrite = false;
  bool permission = true;
  Completer<void>? holdStart;
  @override
  Future<bool> hasPermission({bool request = true}) async => permission;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = path;
    await holdStart?.future;
    await File(
      path,
    ).writeAsBytes(List.generate(3200, (i) => i % 127), flush: true);
    if (failStartAfterWrite) {
      throw StateError('Native start failed after capture');
    }
  }

  @override
  Stream<RecordState> onStateChanged() => states.stream;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Future<String?> stop() async {
    stops++;
    return path;
  }

  @override
  Future<void> cancel() async =>
      throw StateError('Destructive cancel must not be used');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Responses implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  List<int> codes = [200];
  List<String> texts = ['first'];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map<String, dynamic>.from(options.data as Map));
    final index = requests.length - 1;
    final code = codes[index < codes.length ? index : codes.length - 1];
    return ResponseBody.fromString(
      jsonEncode(
        code == 200
            ? {
                'results': [
                  {
                    'alternatives': [
                      {
                        'transcript':
                            texts[index < texts.length
                                ? index
                                : texts.length - 1],
                      },
                    ],
                  },
                ],
              }
            : {
                'error': {'message': 'test failure'},
              },
      ),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SharedPreferences prefs;
  late PendingRecordingStore store;
  late RecorderFake recorder;
  late Responses responses;
  GoogleCloudSpeechProvider provider({bool captureOnly = false}) =>
      GoogleCloudSpeechProvider(
        apiKey: captureOnly ? '' : 'test',
        recorder: recorder,
        recoveryStore: store,
        transcribeOnStop: !captureOnly,
        dio: Dio()..httpClientAdapter = responses,
        delay: (_) async {},
      );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recorder_reliability_');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PendingRecordingStore(
      PrivateStore(prefs),
      directory: () async => Directory('${root.path}/recordings'),
    );
    recorder = RecorderFake();
    responses = Responses();
  });
  tearDown(() async {
    await recorder.states.close();
    await root.delete(recursive: true);
  });
  Future<PendingRecording> raw(int seconds, {String locale = 'te-IN'}) async {
    final item = await store.begin(
      locale,
      entryDate: DateTime(2020, 1, 2),
      folderId: 'original-folder',
    );
    final file = await File(
      await store.capturePath(item.id),
    ).open(mode: FileMode.write);
    try {
      await file.truncate(seconds * 32000);
      await file.flush();
    } finally {
      await file.close();
    }
    return store.get(item.id);
  }

  test(
    'relaunch recovers durable capture and its original language and context',
    () async {
      final item = await raw(3);
      await store.setPhase(item.id, RecordingPhase.recording);
      store = PendingRecordingStore(
        PrivateStore(prefs),
        directory: () async => Directory('${root.path}/recordings'),
      );
      await store.recoverInterrupted();
      final recovered = (await store.list()).single;
      expect(recovered.phase, RecordingPhase.interrupted);
      expect(recovered.locale, 'te-IN');
      expect(recovered.folderId, 'original-folder');
      expect(recovered.entryDate, DateTime(2020, 1, 2));
      expect(recovered.byteLength, 96000);
      await store.sealCapture(item.id);
      expect(await store.readAudio(item.id, 0, 96000), hasLength(96000));
    },
  );
  test('audio-only meeting capture works offline without an API key', () async {
    final capture = provider(captureOnly: true);
    await capture.startListening(
      localeCode: 'te-IN',
      onResult: (_, _) {},
      onError: fail,
    );
    expect((await store.list()).single.locale, 'te-IN');
    await capture.stopListening();
    await capture.cancel();
    expect(responses.requests, isEmpty);
    final saved = (await store.list()).single;
    expect(saved.byteLength, 3200);
    expect(saved.phase, RecordingPhase.completed);
    expect(await File(recorder.path!).exists(), isFalse);
    expect(await store.audio(saved.id), hasLength(3200));
  });
  test(
    'retry reads ID, language and bytes from storage rather than stale UI metadata',
    () async {
      final chosen = await store.retain(
        Uint8List.fromList([1, 2, 3, 4]),
        'te-IN',
      );
      await store.retain(Uint8List.fromList([9, 8]), 'fr-FR');
      await provider().transcribeRetained(
        PendingRecording(
          id: chosen.id,
          locale: 'wrong',
          createdAt: DateTime.now(),
          transcript: 'stale text',
        ),
      );
      expect(responses.requests.single['config']['languageCode'], 'te-IN');
      expect(
        base64Decode(responses.requests.single['audio']['content'] as String),
        [1, 2, 3, 4],
      );
    },
  );
  test(
    'successful chunks survive terminal failure and are not retranscribed after relaunch',
    () async {
      final item = await raw(65);
      responses.codes = [200, 503, 503, 503];
      final cloud = provider();
      await expectLater(
        cloud.transcribeRetained(item),
        throwsA(isA<DioException>()),
      );
      final partial = await store.get(item.id);
      expect(partial.chunks, {0: 'first'});
      expect(partial.transcript, 'first');
      expect(partial.phase, RecordingPhase.failed);
      expect(responses.requests, hasLength(4));
      for (final request in responses.requests) {
        expect(
          base64Decode(request['audio']['content'] as String).length,
          lessThanOrEqualTo(54 * 32000),
        );
      }
      store = PendingRecordingStore(
        PrivateStore(prefs),
        directory: () async => Directory('${root.path}/recordings'),
      );
      responses = Responses()..texts = ['second'];
      expect(
        await provider().transcribeRetained(await store.get(item.id)),
        'first second',
      );
      expect(responses.requests, hasLength(1));
      expect((await store.get(item.id)).chunks, hasLength(2));
      expect((await store.get(item.id)).byteLength, 65 * 32000);
    },
  );
  test('timed overlap assigns a boundary word to exactly one chunk', () {
    final response = {
      'results': [
        {
          'alternatives': [
            {
              'words': [
                {'word': 'before', 'startTime': '1.0s', 'endTime': '1.5s'},
                {'word': 'boundary', 'startTime': '1.8s', 'endTime': '2.2s'},
                {'word': 'after', 'startTime': '2.3s', 'endTime': '2.8s'},
              ],
            },
          ],
        },
      ],
    };
    expect(
      GoogleCloudSpeechProvider.extractChunk(
        response,
        requestStart: 48,
        coreStart: 0,
        coreEnd: 50,
      ),
      'before',
    );
    expect(
      GoogleCloudSpeechProvider.extractChunk(
        response,
        requestStart: 48,
        coreStart: 50,
        coreEnd: 100,
      ),
      'boundary after',
    );
  });
  test(
    'repeated start/stop taps and processing do not overlap or show an active mic',
    () async {
      final speech = FakeSpeech();
      final states = <RecognitionState>[];
      final owner = RecordingCoordinator(
        repository: () => speech,
        requestPermission: () async => true,
      );
      await Future.wait(
        List.generate(
          8,
          (_) =>
              owner.start(tag: 'home', locale: 'en-US', onChanged: states.add),
        ),
      );
      expect(speech.starts, 1);
      final finishing = Completer<void>();
      speech.whenStopped = () => finishing.future;
      final stops = [owner.stop(), owner.stop()];
      await Future<void>.delayed(Duration.zero);
      expect(states.last.isListening, isFalse);
      expect(states.last.isProcessing, isTrue);
      speech.result!('processing result', false);
      expect(states.last.isListening, isFalse);
      speech.result!('done', true);
      finishing.complete();
      await Future.wait(stops);
      expect(speech.stops, 1);
      owner.dispose();
    },
  );
  test(
    'disposal finalizes capture, retains audio, and emits no later UI callback',
    () async {
      final cloud = provider(captureOnly: true);
      final changes = <RecognitionState>[];
      final repo = SpeechRepositoryImpl(cloud);
      final owner = RecordingCoordinator(
        repository: () => repo,
        requestPermission: () async => true,
      );
      await owner.start(
        tag: 'meeting',
        locale: 'en-US',
        onChanged: changes.add,
      );
      owner.dispose();
      final count = changes.length;
      await owner.stop();
      expect(changes.length, count);
      expect((await store.list()).single.byteLength, 3200);
      expect(cloud.isListening, isFalse);
    },
  );
  test(
    'stop during native start waits for start and never leaves the mic active',
    () async {
      recorder.holdStart = Completer<void>();
      final cloud = provider(captureOnly: true);
      final starting = cloud.startListening(
        localeCode: 'te-IN',
        onResult: (_, _) {},
        onError: fail,
      );
      while (recorder.starts == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final stopping = cloud.stopListening();
      recorder.holdStart!.complete();
      await starting;
      await stopping;
      expect(cloud.isListening, isFalse);
      expect((await store.list()).single.byteLength, 3200);
    },
  );
  test('permission denial never starts a recorder', () async {
    recorder.permission = false;
    String? error;
    await provider(captureOnly: true).startListening(
      localeCode: 'en-US',
      onResult: (_, _) {},
      onError: (e) => error = e,
    );
    expect(error, contains('system app settings'));
    expect(recorder.starts, 0);
    expect(await store.list(), isEmpty);
  });
  for (final nativeStartFails in [true, false]) {
    test(
      'startup failure releases mic and retains audio without upload: native=$nativeStartFails',
      () async {
        if (nativeStartFails) {
          recorder.failStartAfterWrite = true;
        } else {
          store = RecordingPhaseFailureStore(
            PrivateStore(prefs),
            directory: () async => Directory('${root.path}/recordings'),
          );
        }
        final cloud = provider();
        final errors = <String>[];
        await cloud.startListening(
          localeCode: 'en-US',
          onResult: (_, _) {},
          onError: errors.add,
        );
        expect(errors, isNotEmpty);
        expect(cloud.isListening, isFalse);
        expect(recorder.stops, 1);
        expect(responses.requests, isEmpty);
        final item = (await store.list()).single;
        expect(item.phase, RecordingPhase.interrupted);
        expect(await store.audio(item.id), hasLength(3200));
        await cloud.cancel();
        expect(recorder.stops, 1);
      },
    );
  }
  test(
    'cancelled upload stays interrupted in the UI with audio retained',
    () async {
      final cloud = provider();
      final states = <RecognitionState>[];
      final owner = RecordingCoordinator(
        repository: () => SpeechRepositoryImpl(cloud),
        requestPermission: () async => true,
      );
      await owner.start(tag: 'home', locale: 'en-US', onChanged: states.add);
      await owner.stop(cancelTranscription: true);
      expect(states.last.phase, RecordingPhase.interrupted);
      expect(states.last.audioSaved, isTrue);
      expect(states.last.isListening, isFalse);
      expect(states.last.isProcessing, isFalse);
      expect(responses.requests, isEmpty);
      expect(
        await store.audio((await store.list()).single.id),
        hasLength(3200),
      );
      owner.dispose();
    },
  );
  test(
    'failed transcription stays failed in the UI with audio retained',
    () async {
      responses.codes = [401];
      final cloud = provider();
      final states = <RecognitionState>[];
      final owner = RecordingCoordinator(
        repository: () => SpeechRepositoryImpl(cloud),
        requestPermission: () async => true,
      );
      await owner.start(tag: 'home', locale: 'en-US', onChanged: states.add);
      await owner.stop();
      expect(states.last.phase, RecordingPhase.failed);
      expect(states.last.errorMessage, contains('Audio is kept'));
      expect(states.last.audioSaved, isTrue);
      expect(states.last.isProcessing, isFalse);
      expect(
        await store.audio((await store.list()).single.id),
        hasLength(3200),
      );
      owner.dispose();
    },
  );
  test(
    'recovery history IDs remain unique across a crash before acknowledgement',
    () async {
      final item = await store.retain(Uint8List.fromList([1, 2]), 'te-IN');
      final history = HistoryRepositoryImpl(HistoryLocalDataSource(prefs));
      final entry = HistoryItem(
        id: item.transcriptId,
        sourceText: 'saved',
        sourceLanguageCode: 'te',
        timestamp: item.createdAt,
      );
      await history.add(entry); // Crash before store.markSaved.
      await Future.wait([history.add(entry), history.add(entry)]);
      await store.markSaved(item.id);
      expect(await history.getAll(), hasLength(1));
      expect(await store.audio(item.id), [1, 2]);
    },
  );
  test(
    'explicit deletion removes only the exact recording and its chunk files',
    () async {
      final first = await store.retain(Uint8List.fromList([1, 2]), 'en-US');
      final other = await store.retain(Uint8List.fromList([3, 4]), 'te-IN');
      await store.saveChunk(first.id, 0, 'private text');
      await store.delete(first.id);
      expect((await store.list()).single.id, other.id);
      expect(await store.audio(other.id), [3, 4]);
      expect(
        await Directory(
          '${root.path}/recordings',
        ).list().any((e) => e.uri.pathSegments.last.startsWith('${first.id}.')),
        isFalse,
      );
    },
  );
  test(
    'legacy encrypted recordings and orphaned temporary PCM are preserved',
    () async {
      final directory = await Directory(
        '${root.path}/recordings',
      ).create(recursive: true);
      await File('${directory.path}/123.json').writeAsString(
        await PrivateStore(prefs).seal(
          jsonEncode({
            'id': '123',
            'locale': 'te-IN',
            'createdAt': DateTime(2020).toIso8601String(),
            'audio': base64Encode([1, 2, 3, 4]),
            'transcript': 'old transcript',
          }),
        ),
      );
      final temporary = await Directory('${root.path}/temporary').create();
      await File('${temporary.path}/gcloud_stt_456.pcm').writeAsBytes([5, 6]);
      await store.importLegacyTemporary(temporary);
      await store.importLegacyTemporary(temporary);
      expect(await store.audio('123'), [1, 2, 3, 4]);
      expect((await store.get('123')).transcript, 'old transcript');
      expect(await store.audio('456'), [5, 6]);
      expect((await store.get('456')).locale, 'und');
      await store.setUnknownLocale('456', 'te-IN');
      expect((await store.get('456')).locale, 'te-IN');
      expect(await store.list(), hasLength(2));
    },
  );
  test(
    'corrupt metadata cannot hide other recordings or discard their audio',
    () async {
      final item = await store.retain(Uint8List.fromList([1, 2]), 'en-US');
      await File('${root.path}/recordings/999.json').writeAsString('broken');
      final items = await store.list();
      expect(items, hasLength(2));
      expect(items.singleWhere((r) => r.id == '999').error, contains('kept'));
      expect(await store.audio(item.id), [1, 2]);
    },
  );
  test(
    'corrupt staging file cannot block recovery of a healthy capture',
    () async {
      final item = await raw(2);
      await store.setPhase(item.id, RecordingPhase.recording);
      final corrupt = File('${root.path}/recordings/999.json.tmp');
      await corrupt.writeAsString('incomplete encrypted write', flush: true);
      await store.recoverInterrupted();
      expect((await store.get(item.id)).phase, RecordingPhase.interrupted);
      expect(await store.audio(item.id), hasLength(64000));
      expect(await corrupt.readAsString(), 'incomplete encrypted write');
    },
  );
  test(
    'WAV export preserves every PCM byte and writes a valid length header',
    () async {
      final item = await raw(2);
      await store.sealCapture(item.id);
      final file = await store.exportWav(
        item.id,
        Directory('${root.path}/exports'),
      );
      final bytes = await file.readAsBytes();
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 64000);
      expect(bytes.length, 64044);
      expect(bytes.sublist(44), await store.audio(item.id));
    },
  );
  test('disk-full sealing preserves the only durable raw copy', () async {
    final failing = SealingFailureStore(prefs);
    store = PendingRecordingStore(
      failing,
      directory: () async => Directory('${root.path}/recordings'),
    );
    final item = await raw(2);
    failing.failWrites = true;
    await expectLater(
      store.sealCapture(item.id),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(await store.capturePath(item.id)).length(), 64000);
    final reopened = PendingRecordingStore(
      PrivateStore(prefs),
      directory: () async => Directory('${root.path}/recordings'),
    );
    expect(await reopened.audio(item.id), hasLength(64000));
  });
  test(
    'disposing a Cloud session stops capture without starting a new upload',
    () async {
      final cloud = provider();
      final owner = RecordingCoordinator(
        repository: () => SpeechRepositoryImpl(cloud),
        requestPermission: () async => true,
      );
      await owner.start(tag: 'home', locale: 'en-US', onChanged: (_) {});
      owner.dispose();
      await owner.stop();
      expect(responses.requests, isEmpty);
      expect((await store.list()).single.byteLength, 3200);
      expect((await store.list()).single.phase, RecordingPhase.interrupted);
    },
  );
  test(
    'native pause interrupts capture and retains audio without auto-resume',
    () async {
      final cloud = provider(captureOnly: true);
      final owner = RecordingCoordinator(
        repository: () => SpeechRepositoryImpl(cloud),
        requestPermission: () async => true,
      );
      await owner.start(tag: 'meeting', locale: 'en-US', onChanged: (_) {});
      recorder.states.add(RecordState.pause);
      await owner.stop();
      expect(cloud.isListening, isFalse);
      expect((await store.list()).single.phase, RecordingPhase.interrupted);
      expect((await store.list()).single.byteLength, 3200);
      expect(recorder.starts, 1);
      owner.dispose();
    },
  );
  test(
    'transient failures use bounded backoff and terminal auth failures do not loop',
    () async {
      final item = await store.retain(Uint8List.fromList([1, 2]), 'en-US');
      responses.codes = [503, 503, 200];
      final delays = <Duration>[];
      final cloud = GoogleCloudSpeechProvider(
        apiKey: 'test',
        recoveryStore: store,
        dio: Dio()..httpClientAdapter = responses,
        delay: (d) async {
          delays.add(d);
        },
      );
      await cloud.transcribeRetained(item);
      expect(delays, [
        const Duration(milliseconds: 500),
        const Duration(seconds: 1),
      ]);
      final next = await store.retain(Uint8List.fromList([3, 4]), 'te-IN');
      responses = Responses()..codes = [401];
      await expectLater(
        provider().transcribeRetained(next),
        throwsA(isA<DioException>()),
      );
      expect(responses.requests, hasLength(1));
      expect(await store.audio(next.id), [3, 4]);
    },
  );
}
