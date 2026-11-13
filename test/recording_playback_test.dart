import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/recording_playback_controller.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/google_cloud_speech_provider.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/transcript_segment.dart';

class PlaybackFake implements AudioPlayer {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final completed = StreamController<void>.broadcast(sync: true);
  @override
  DeviceFileSource? source;
  Duration? sought;
  int resumes = 0, pauses = 0, disposals = 0;
  Completer<void>? sourceReady;
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Stream<void> get onPlayerComplete => completed.stream;
  @override
  Future<void> setSource(Source value) async {
    source = value as DeviceFileSource;
    await sourceReady?.future;
  }

  @override
  Future<void> seek(Duration value) async {
    sought = value;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PendingRecordingStore store;
  late RecordingPlaybackController player;
  late List<PlaybackFake> natives;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('voice_playback_test_');
    store = PendingRecordingStore(
      PrivateStore(await SharedPreferences.getInstance()),
      directory: () async => Directory('${root.path}/audio'),
    );
    natives = [];
    player = RecordingPlaybackController(
      store,
      temporary: () async => root,
      playerFactory: () {
        final native = PlaybackFake();
        natives.add(native);
        return native;
      },
    );
  });
  tearDown(() async {
    await player.stop();
    player.dispose();
    for (final native in natives) {
      await native.positions.close();
      await native.completed.close();
    }
    await root.delete(recursive: true);
  });

  test(
    'decrypts original audio, seeks, pauses and removes only playback cache on stop',
    () async {
      final bytes = Uint8List.fromList(List.generate(64000, (i) => i % 127));
      final item = await store.retain(bytes, 'te-IN');
      await player.play(item.id, from: const Duration(milliseconds: 700));
      final native = natives.single;
      final wav = File(native.source!.path);
      final contents = await wav.readAsBytes();
      expect(String.fromCharCodes(contents.take(4)), 'RIFF');
      expect(contents.sublist(44), bytes);
      expect(native.sought, const Duration(milliseconds: 700));
      expect(player.playing, isTrue);
      await player.pause();
      expect(player.playing, isFalse);
      await player.seek(const Duration(seconds: 99));
      expect(native.sought, const Duration(seconds: 2));
      await player.play(item.id);
      expect(natives, hasLength(1));
      await player.stop();
      expect(native.disposals, 1);
      expect(await wav.exists(), isFalse);
      expect(await store.audio(item.id), bytes);
    },
  );
  test(
    'switching notes releases the first player and decrypted file',
    () async {
      final first = await store.retain(Uint8List(32000), 'en-US');
      final second = await store.retain(Uint8List(32000), 'hi-IN');
      await player.play(first.id);
      final firstFile = File(natives.first.source!.path);
      await player.play(second.id);
      expect(natives.first.disposals, 1);
      expect(await firstFile.exists(), isFalse);
      expect(player.recordingId, second.id);
    },
  );
  test(
    'background stop while preparation is pending cannot resume late audio',
    () async {
      final item = await store.retain(Uint8List(32000), 'en-US');
      final gate = Completer<void>();
      player.dispose();
      player = RecordingPlaybackController(
        store,
        temporary: () async => root,
        playerFactory: () {
          final native = PlaybackFake()..sourceReady = gate;
          natives.add(native);
          return native;
        },
      );
      final starting = player.play(item.id);
      while (natives.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final stopping = player.stop();
      gate.complete();
      await Future.wait([starting, stopping]);
      expect(natives.single.resumes, 0);
      expect(player.playing, isFalse);
      expect(await File(natives.single.source!.path).exists(), isFalse);
    },
  );
  test(
    'missing audio reports a recoverable error without deleting another clip',
    () async {
      final other = await store.retain(Uint8List(32000), 'en-US');
      await player.play('999999');
      expect(player.error, contains('Your text is kept'));
      expect((await store.get(other.id)).byteLength, 32000);
    },
  );
  test(
    'timed checkpoints survive a restart and engine changes without mixing',
    () async {
      final item = await store.retain(Uint8List(64000), 'en-US');
      const word = TranscriptSegment(
        text: 'hello',
        start: Duration(milliseconds: 250),
        end: Duration(milliseconds: 750),
      );
      await store.saveChunk(item.id, 0, 'hello', segments: [word]);
      await store.selectTranscriptionBackend(item.id, 'whisperBase30v1');
      expect((await store.get(item.id)).segments, isEmpty);
      await store.saveChunk(item.id, 0, 'offline');
      await store.selectTranscriptionBackend(item.id, 'googleCloud');
      final reopened = PendingRecordingStore(
        store.store,
        directory: () async => Directory('${root.path}/audio'),
      );
      final restored = await reopened.get(item.id);
      expect(restored.transcript, 'hello');
      expect(restored.segments.single.toJson(), word.toJson());
    },
  );
  test(
    'cloud word offsets account for overlap and retain a boundary word once',
    () {
      final response = <String, dynamic>{
        'results': [
          {
            'alternatives': [
              {
                'words': [
                  {'word': 'before', 'startTime': '0s', 'endTime': '1s'},
                  {'word': 'boundary', 'startTime': '1.8s', 'endTime': '2.2s'},
                  {'word': 'after', 'startTime': '3s', 'endTime': '4s'},
                ],
              },
            ],
          },
        ],
      };
      final segments = GoogleCloudSpeechProvider.extractSegments(
        response,
        requestStart: 48,
        coreStart: 50,
        coreEnd: 100,
      );
      expect(segments.map((s) => s.text), ['boundary', 'after']);
      expect(segments.first.start, const Duration(milliseconds: 49800));
      expect(segments.last.end, const Duration(seconds: 52));
    },
  );
  test(
    'a platform playback error stops safely and preserves the original',
    () async {
      final item = await store.retain(Uint8List(32000), 'en-US');
      await player.play(item.id);
      natives.single.completed.addError(
        StateError('Audio device disconnected'),
      );
      await player.stop();
      expect(player.playing, isFalse);
      expect(player.error, contains('Your original audio is kept'));
      expect((await store.get(item.id)).byteLength, 32000);
    },
  );
  test(
    'startup cleanup removes playback cache and preserves unrelated files',
    () async {
      final scratch = await Directory(
        '${root.path}/voicedocsai_playback/clip_old',
      ).create(recursive: true);
      await File('${scratch.path}/private.wav').writeAsBytes([1, 2]);
      final keep = await Directory(
        '${root.path}/voicedocsai_playback/keep',
      ).create();
      await RecordingPlaybackController.cleanupScratch(root);
      expect(await scratch.exists(), isFalse);
      expect(await keep.exists(), isTrue);
    },
  );
}
