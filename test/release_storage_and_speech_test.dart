import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/privacy/local_data_service.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/google_cloud_speech_provider.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/repositories/speech_repository_impl.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'support/fakes.dart';

class _Recorder implements AudioRecorder {
  String? path;
  bool returnNullPath = false;
  final audio = Uint8List.fromList(List.generate(3200, (i) => i % 127));
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
    this.path = path;
    await File(path).writeAsBytes(audio);
  }

  @override
  Future<String?> stop() async => returnNullPath ? null : path;
  @override
  Future<void> cancel() async {}
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Responses implements HttpClientAdapter {
  int status = 503;
  String transcript = 'My recovered diary';
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(
        status == 200
            ? {
                'results': [
                  {
                    'alternatives': [
                      {'transcript': transcript},
                    ],
                  },
                ],
              }
            : {
                'error': {'message': 'Simulated unavailable service'},
              },
      ),
      status,
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
  late PrivateStore privateStore;
  late PendingRecordingStore recovery;
  late _Recorder recorder;
  late _Responses responses;
  late GoogleCloudSpeechProvider cloud;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('voice_release_test_');
    PathProviderPlatform.instance = FakePaths(root.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    privateStore = PrivateStore(prefs);
    recovery = PendingRecordingStore(
      privateStore,
      directory: () async => Directory('${root.path}/pending_cloud_recordings'),
    );
    recorder = _Recorder();
    responses = _Responses();
    cloud = GoogleCloudSpeechProvider(
      apiKey: 'test-only',
      recoveryStore: recovery,
      recorder: recorder,
      dio: Dio()..httpClientAdapter = responses,
    );
  });
  tearDown(() async => root.delete(recursive: true));

  Future<void> capture({
    void Function(String, bool)? result,
    void Function(String)? error,
  }) async {
    await cloud.startListening(
      localeCode: 'en-US',
      onResult: result ?? (_, _) {},
      onError: error ?? (_) {},
    );
    await cloud.stopListening();
  }

  test('capture is discoverable before stop or transcription', () async {
    await cloud.startListening(
      localeCode: 'te-IN',
      onResult: (_, _) {},
      onError: (_) {},
    );
    final reopened = PendingRecordingStore(
      PrivateStore(prefs),
      directory: () async => Directory('${root.path}/pending_cloud_recordings'),
    );
    final saved = (await reopened.list()).single;
    expect(saved.locale, 'te-IN');
    expect(await reopened.audio(saved.id), recorder.audio);
    await cloud.cancel();
  });

  test(
    'failed upload keeps encrypted audio across store reopen and allows retry',
    () async {
      String? error;
      await capture(error: (message) => error = message);
      expect(error, contains('Recover recordings'));
      expect(await File(recorder.path!).exists(), isFalse);
      final reopened = PendingRecordingStore(
        PrivateStore(prefs),
        directory: () async =>
            Directory('${root.path}/pending_cloud_recordings'),
      );
      final saved = (await reopened.list()).single;
      expect(await reopened.audio(saved.id), recorder.audio);
      final raw = await File(
        '${root.path}/pending_cloud_recordings/${saved.id}.json',
      ).readAsString();
      expect(raw, isNot(contains(base64Encode(recorder.audio))));
      expect(raw, isNot(contains('en-US')));
      responses.status = 200;
      expect(await cloud.transcribeRetained(saved), 'My recovered diary');
      expect((await reopened.list()).single.transcript, 'My recovered diary');
      expect(await reopened.audio(saved.id), recorder.audio);
    },
  );

  test(
    'successful transcription and history acknowledgement retain audio until explicit deletion',
    () async {
      responses.status = 200;
      String? text;
      await capture(result: (value, finalResult) => text = value);
      expect(text, 'My recovered diary');
      expect(await recovery.list(), hasLength(1));
      await cloud.confirmSaved();
      expect((await recovery.list()).single.historyId, isNotNull);
      expect(
        await recovery.audio((await recovery.list()).single.id),
        recorder.audio,
      );
    },
  );

  test(
    'history save failure retains a ready transcript for recovery',
    () async {
      responses.status = 200;
      final repository = SpeechRepositoryImpl(cloud);
      final coordinator = RecordingCoordinator(
        repository: () => repository,
        requestPermission: () async => true,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start(
        tag: 'home',
        locale: 'en-US',
        onChanged: (_) {},
        save: (_) async => throw const FileSystemException('Disk full'),
      );
      await coordinator.stop();
      expect((await recovery.list()).single.transcript, 'My recovered diary');
    },
  );

  test(
    'empty recognition does not claim success or discard the capture',
    () async {
      responses.status = 200;
      responses.transcript = '';
      var finals = 0;
      String? error;
      await capture(
        result: (_, _) => finals++,
        error: (value) => error = value,
      );
      expect(finals, 0);
      expect(error, contains('No speech'));
      expect(await recovery.list(), hasLength(1));
    },
  );

  test('a missing stop path still secures the known capture file', () async {
    recorder.returnNullPath = true;
    await capture();
    expect(await recovery.list(), hasLength(1));
    expect(await File(recorder.path!).exists(), isFalse);
  });

  test(
    'authenticated recovery storage rejects altered audio envelopes',
    () async {
      final saved = await recovery.retain(recorder.audio, 'en-US');
      final file = File(
        '${root.path}/pending_cloud_recordings/${saved.id}.json',
      );
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data['mac'] = base64Encode(List.filled(16, 0));
      await file.writeAsString(jsonEncode(data));
      await expectLater(recovery.audio(saved.id), throwsA(anything));
    },
  );

  test(
    'capacity blocks new audio without deleting existing recordings',
    () async {
      for (var i = 0; i < PendingRecordingStore.maxRecordings; i++) {
        await recovery.retain(recorder.audio, 'en-US');
      }
      await expectLater(
        recovery.retain(recorder.audio, 'en-US'),
        throwsStateError,
      );
      expect(
        await recovery.list(),
        hasLength(PendingRecordingStore.maxRecordings),
      );
    },
  );

  test(
    'delete all removes known data and encryption key, preserves unrelated files',
    () async {
      final oldCiphertext = await privateStore.seal('private diary');
      await privateStore.write('private-record', '{"text":"private diary"}');
      final photoDir = await Directory('${root.path}/diary_photos').create();
      await File('${photoDir.path}/photo.jpg').writeAsString('photo');
      await File('${root.path}/profile_avatar.jpg').writeAsString('avatar');
      await File(
        '${root.path}/auto_backup_before_reset.json',
      ).writeAsString('backup');
      await File(
        '${root.path}/voicedocsai_export.json',
      ).writeAsString('export');
      await File('${root.path}/unrelated.txt').writeAsString('keep');
      await recovery.retain(recorder.audio, 'en-US');
      final operations = <String>[];
      await LocalDataService(
        prefs: prefs,
        stopRecording: () async => operations.add('stop'),
        cancelReminders: () async => operations.add('cancel'),
        documents: () async => root,
        temporary: () async => root,
      ).deleteAll();
      expect(operations, ['stop', 'cancel']);
      expect(prefs.getKeys(), isEmpty);
      expect(await File('${root.path}/unrelated.txt').exists(), isTrue);
      expect(await photoDir.exists(), isFalse);
      expect(
        await File('${root.path}/voicedocsai_export.json').exists(),
        isFalse,
      );
      expect(await recovery.list(), isEmpty);
      await expectLater(privateStore.open(oldCiphertext), throwsA(anything));
      expect(
        await privateStore.open(await privateStore.seal('new profile')),
        'new profile',
      );
    },
  );

  test(
    'reminder cancellation failure does not claim completed data deletion',
    () async {
      await prefs.setString('keep', 'value');
      await expectLater(
        LocalDataService(
          prefs: prefs,
          stopRecording: () async {},
          cancelReminders: () async => throw StateError('Plugin failed'),
          documents: () async => root,
          temporary: () async => root,
        ).deleteAll(),
        throwsStateError,
      );
      expect(prefs.getString('keep'), 'value');
    },
  );
}
