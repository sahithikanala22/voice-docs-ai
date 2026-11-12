import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/settings/data/settings_local_datasource.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:ai_voice_docs/features/settings/presentation/screens/settings_screen.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/whisper_speech_provider.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/repositories/speech_repository_impl.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/whisper_model_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recognition_state.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_phase.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/whisper_providers.dart';

class ModelResponses implements HttpClientAdapter {
  List<int> bytes = [1, 2, 3, 4];
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? request,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FileRecorder implements AudioRecorder {
  int starts = 0;
  String? path;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = path;
    await File(path).writeAsBytes(List<int>.filled(160000, 7), flush: true);
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async => throw StateError('Must never delete capture');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalInference implements OfflineWhisperTranscriber {
  int calls = 0;
  int? failAt;
  Completer<void>? hold;
  List<WhisperWord> Function(int)? words;
  final languages = <String>[];
  final pcmLengths = <int>[];
  @override
  Future<List<WhisperWord>> transcribe({
    required String audioPath,
    required String modelPath,
    required String language,
  }) async {
    calls++;
    languages.add(language);
    final bytes = await File(audioPath).readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    pcmLengths.add(bytes.length - 44);
    await hold?.future;
    if (calls == failAt) throw StateError('Native inference failed');
    if (words != null) return words!(calls);
    return [
      WhisperWord(
        'chunk$calls',
        const Duration(seconds: 3),
        const Duration(seconds: 4),
      ),
    ];
  }
}

class ModelUiStore extends WhisperModelStore {
  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SharedPreferences prefs;
  late PendingRecordingStore recordings;
  late WhisperModelStore models;
  late ModelResponses network;
  late LocalInference inference;
  final modelBytes = [1, 2, 3, 4];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('whisper_offline_test_');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    recordings = PendingRecordingStore(
      PrivateStore(prefs),
      directory: () async => Directory('${root.path}/audio'),
    );
    network = ModelResponses();
    models = WhisperModelStore(
      dio: Dio()..httpClientAdapter = network,
      directory: () async => Directory('${root.path}/models'),
      artifact: WhisperModelArtifact(
        uri: 'https://model.test/base.bin',
        bytes: 4,
        sha256: crypto.sha256.convert(modelBytes).toString(),
      ),
    );
    inference = LocalInference();
  });
  tearDown(() async {
    models.dispose();
    await root.delete(recursive: true);
  });
  Future<void> installModel() async {
    final file = await models.modelFile;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(modelBytes, flush: true);
  }

  Future<PendingRecording> capture(
    int seconds, {
    String language = 'te-IN',
  }) async {
    final item = await recordings.begin(language);
    final file = await File(
      await recordings.capturePath(item.id),
    ).open(mode: FileMode.write);
    try {
      await file.truncate(seconds * 32000);
      await file.flush();
    } finally {
      await file.close();
    }
    return recordings.get(item.id);
  }

  WhisperSpeechProvider provider({FileRecorder? recorder}) =>
      WhisperSpeechProvider(
        models: models,
        transcriber: inference,
        recorder: recorder,
        recoveryStore: recordings,
        temporary: () async => root,
      );

  test(
    'readiness requires verified bytes; partial/corrupt files are never ready',
    () async {
      final file = await models.modelFile;
      await file.parent.create(recursive: true);
      await File('${file.path}.part').writeAsBytes(modelBytes);
      expect(await models.verifiedPath(), isNull);
      await file.writeAsBytes([4, 3, 2, 1]);
      await models.refresh();
      expect(models.state.phase, WhisperModelPhase.missing);
      await expectLater(models.requireReady(), throwsStateError);
      await installModel();
      await models.refresh();
      expect(models.state.phase, WhisperModelPhase.ready);
      expect(await models.requireReady(), file.path);
      await file.delete();
      expect(await models.verifiedPath(), isNull);
      expect(network.calls, 0);
    },
  );

  test(
    'failed model integrity check can retry with progress and atomic readiness',
    () async {
      final phases = <WhisperModelPhase>[];
      final subscription = models.changes.listen((s) => phases.add(s.phase));
      network.bytes = [4, 3, 2, 1];
      await models.download();
      expect(models.state.phase, WhisperModelPhase.failed);
      expect(await (await models.modelFile).exists(), isFalse);
      network.bytes = modelBytes;
      await models.download();
      expect(models.state.phase, WhisperModelPhase.ready);
      expect(await models.requireReady(), isNotEmpty);
      expect(network.calls, 2);
      expect(
        phases,
        containsAllInOrder([
          WhisperModelPhase.downloading,
          WhisperModelPhase.verifying,
          WhisperModelPhase.failed,
          WhisperModelPhase.downloading,
          WhisperModelPhase.verifying,
          WhisperModelPhase.ready,
        ]),
      );
      expect(
        await File('${(await models.modelFile).path}.part').exists(),
        isFalse,
      );
      await subscription.cancel();
    },
  );
  test(
    'repeated model download taps share a single verified download',
    () async {
      await Future.wait([
        models.download(),
        models.download(),
        models.download(),
      ]);
      expect(network.calls, 1);
      expect(models.state.phase, WhisperModelPhase.ready);
    },
  );
  test('a changed model is reverified before offline inference', () async {
    await installModel();
    await models.requireReady();
    final file = await models.modelFile;
    await file.writeAsBytes([4, 3, 2, 1]);
    await file.setLastModified(DateTime.now().add(const Duration(seconds: 2)));
    await expectLater(models.requireReady(), throwsStateError);
    expect(network.calls, 0);
  });

  test(
    'missing model and native inference failure preserve durable audio for retry',
    () async {
      final item = await capture(5);
      await expectLater(provider().transcribeRetained(item), throwsStateError);
      expect((await recordings.get(item.id)).byteLength, 160000);
      expect(inference.calls, 0);
      await installModel();
      inference.failAt = 1;
      await expectLater(provider().transcribeRetained(item), throwsStateError);
      expect(await recordings.audio(item.id), hasLength(160000));
      inference.failAt = null;
      expect(await provider().transcribeRetained(item), 'chunk2');
      expect(await recordings.audio(item.id), hasLength(160000));
      expect(inference.languages, ['te', 'te']);
      expect(
        network.calls,
        0,
      ); // No model download or cloud fallback during retry.
    },
  );

  test(
    'offline chunks survive relaunch and retry skips completed chunks',
    () async {
      await installModel();
      final item = await capture(65, language: 'hi-IN');
      inference.failAt = 2;
      await expectLater(provider().transcribeRetained(item), throwsStateError);
      expect((await recordings.get(item.id)).chunks.keys, [0]);
      recordings = PendingRecordingStore(
        PrivateStore(prefs),
        directory: () async => Directory('${root.path}/audio'),
      );
      await recordings.recoverInterrupted();
      inference.failAt = null;
      expect(await provider().transcribeRetained(item), 'chunk1 chunk3 chunk4');
      expect(inference.calls, 4);
      expect(inference.languages.toSet(), {'hi'});
      expect(inference.pcmLengths.every((n) => n <= 34 * 32000), isTrue);
      expect((await recordings.get(item.id)).byteLength, 65 * 32000);
      expect(network.calls, 0);
    },
  );

  test(
    'changing engine keeps separate checkpoints and original audio',
    () async {
      final item = await capture(5);
      await recordings.saveChunk(item.id, 0, 'cloud partial');
      await recordings.selectTranscriptionBackend(
        item.id,
        WhisperSpeechProvider.backend,
      );
      expect((await recordings.get(item.id)).chunks, isEmpty);
      await recordings.saveChunk(item.id, 0, 'offline partial');
      await recordings.selectTranscriptionBackend(item.id, 'googleCloud');
      expect((await recordings.get(item.id)).transcript, 'cloud partial');
      await recordings.selectTranscriptionBackend(
        item.id,
        WhisperSpeechProvider.backend,
      );
      expect((await recordings.get(item.id)).transcript, 'offline partial');
      expect((await recordings.get(item.id)).byteLength, 160000);
    },
  );
  test(
    'scratch recovery and deletion preserve other jobs and durable recordings',
    () async {
      final item = await capture(5);
      final other = await capture(5);
      final cache = Directory('${root.path}/voicedocsai_whisper_jobs');
      final firstScratch = await Directory(
        '${cache.path}/${item.id}_old',
      ).create(recursive: true);
      final otherScratch = await Directory(
        '${cache.path}/${other.id}_old',
      ).create();
      await File('${firstScratch.path}/chunk.wav').writeAsBytes([1, 2]);
      await File('${otherScratch.path}/chunk.wav').writeAsBytes([3, 4]);
      await WhisperSpeechProvider.cleanupScratch(root, recordingId: item.id);
      expect(await firstScratch.exists(), isFalse);
      expect(await otherScratch.exists(), isTrue);
      expect((await recordings.get(item.id)).byteLength, 160000);
      await WhisperSpeechProvider.cleanupScratch(root);
      expect(await otherScratch.exists(), isFalse);
      expect((await recordings.get(other.id)).byteLength, 160000);
    },
  );
  test(
    'timed overlap assigns a word crossing 30 seconds to one chunk',
    () async {
      await installModel();
      final item = await capture(35);
      inference.words = (call) => call == 1
          ? [
              const WhisperWord(
                'before',
                Duration(seconds: 28),
                Duration(seconds: 29),
              ),
              const WhisperWord(
                'boundary',
                Duration(milliseconds: 29800),
                Duration(milliseconds: 30200),
              ),
            ]
          : [
              const WhisperWord(
                'boundary',
                Duration(milliseconds: 1800),
                Duration(milliseconds: 2200),
              ),
              const WhisperWord(
                'after',
                Duration(seconds: 3),
                Duration(seconds: 4),
              ),
            ];
      expect(
        await provider().transcribeRetained(item),
        'before boundary after',
      );
    },
  );

  test(
    'local processing has microphone off and cancellation discards late results',
    () async {
      await installModel();
      inference.hold = Completer<void>();
      final recorder = FileRecorder();
      final engine = provider(recorder: recorder);
      final states = <RecognitionState>[];
      final saved = <String>[];
      final owner = RecordingCoordinator(
        repository: () => SpeechRepositoryImpl(engine),
        requestPermission: () async => true,
      );
      await Future.wait([
        for (var i = 0; i < 3; i++)
          owner.start(
            tag: 'home',
            locale: 'en-US',
            onChanged: states.add,
            save: (s) async {
              saved.add(s);
            },
          ),
      ]);
      final stopping = owner.stop();
      while (inference.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(engine.isListening, isFalse);
      expect(states.last.phase, RecordingPhase.transcribing);
      expect(states.last.isListening, isFalse);
      expect(states.last.audioSaved, isTrue);
      expect(recorder.starts, 1);
      final cancelled = owner.stop(cancelTranscription: true);
      inference.hold!.complete();
      await Future.wait([stopping, cancelled]);
      expect(saved, isEmpty);
      expect(states.last.phase, RecordingPhase.interrupted);
      final item = (await recordings.list()).single;
      expect(item.chunks, isEmpty);
      expect(await recordings.audio(item.id), hasLength(160000));
      owner.dispose();
    },
  );

  test(
    'English Hindi Telugu locale routing and settings persist without cloud credentials',
    () async {
      for (final locale in {
        'en-US': 'en',
        'hi-IN': 'hi',
        'te-IN': 'te',
      }.entries) {
        expect(WhisperSpeechProvider.languageFor(locale.key), locale.value);
      }
      final source = SettingsLocalDataSource(prefs);
      await source.write(const AppSettings(speechEngine: SpeechEngine.whisper));
      final restored = await source.read();
      expect(restored.speechEngine, SpeechEngine.whisper);
      expect(restored.googleCloudApiKey, isNull);
    },
  );

  testWidgets(
    'Whisper is visible in Settings and selects the offline provider',
    (tester) async {
      final uiModels = ModelUiStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            biometricAvailableProvider.overrideWith((ref) async => false),
            whisperModelStoreProvider.overrideWithValue(uiModels),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Whisper — Free Offline'), findsOneWidget);
      await tester.tap(find.text('Whisper — Free Offline'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(
        container.read(settingsControllerProvider).value!.speechEngine,
        SpeechEngine.whisper,
      );
      expect(
        container.read(speechProviderImplProvider),
        isA<WhisperSpeechProvider>(),
      );
      expect(find.text('Download model'), findsOneWidget);
      expect(find.textContaining('Model not downloaded'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      uiModels.dispose();
    },
  );
}
