import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recognition_state.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_coordinator.dart';
import 'support/fakes.dart';

void main() {
  late FakeSpeech speech;
  late RecordingCoordinator owner;
  final saved = <String>[];
  final states = <RecognitionState>[];
  Future<void> start([String tag = 'home']) => owner.start(
    tag: tag,
    locale: 'en-US',
    onChanged: states.add,
    save: tag == 'home'
        ? (text) async {
            saved.add(text);
          }
        : null,
  );
  setUp(() {
    speech = FakeSpeech();
    saved.clear();
    states.clear();
    owner = RecordingCoordinator(
      repository: () => speech,
      requestPermission: () async => true,
      finalResultTimeout: const Duration(milliseconds: 40),
    );
  });
  tearDown(() => owner.dispose());
  test('waits for a late final result and saves it exactly once', () async {
    speech.whenStopped = () async {
      Timer(
        const Duration(milliseconds: 10),
        () => speech.result!('complete final transcript', true),
      );
    };
    await start();
    speech.result!('partial', false);
    await Future.wait([owner.stop(), owner.stop()]);
    expect(saved, ['complete final transcript']);
    expect(states.last.isListening, isFalse);
    expect(speech.isListening, isFalse);
    speech.result!('late duplicate', true);
    expect(saved, hasLength(1));
  });
  test('a new capture ends the previous owner before starting', () async {
    await start();
    await start('tasks-add');
    expect(saved, ['final words']);
    expect(speech.starts, 2);
    expect(speech.stops, 1);
    expect(speech.isListening, isTrue);
    await owner.stop(tag: 'home');
    expect(speech.stops, 1);
    await owner.stop();
    expect(saved, hasLength(1));
  });
  test('stops the original engine after settings switch', () async {
    final original = speech;
    await start();
    speech = FakeSpeech();
    await owner.stop();
    expect(original.stops, 1);
    expect(original.cancels, 1);
    expect(speech.stops, 0);
    await start('dictation');
    expect(speech.starts, 1);
    await owner.stop();
  });
  test(
    'navigation while permission is pending prevents a late recording',
    () async {
      final permission = Completer<bool>();
      owner.dispose();
      owner = RecordingCoordinator(
        repository: () => speech,
        requestPermission: () => permission.future,
      );
      final starting = start();
      await Future<void>.delayed(Duration.zero);
      await owner.stop();
      permission.complete(true);
      await starting;
      expect(speech.starts, 0);
    },
  );
  test('navigation invalidates starts queued in the same event turn', () async {
    final starting = start();
    await owner.stop();
    await starting;
    expect(speech.starts, 0);
  });
  test(
    'an interruption stops the microphone and retains available words',
    () async {
      await start();
      speech.result!('words before interruption', false);
      speech.whenStopped = () async {
        throw StateError('interrupted');
      };
      speech.error!('audio interruption');
      await owner.stop();
      expect(saved, ['words before interruption']);
      expect(speech.isListening, isFalse);
    },
  );
  test('a natural final result saves without any screen listener', () async {
    await start();
    speech.result!('natural final', true);
    await owner.stop();
    expect(saved, ['natural final']);
  });
}
