import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:ai_voice_docs/features/speech_to_text/data/providers/on_device_speech_provider.dart';

/// Stands in for the native recognizer: records how often a session is
/// started, and lets a test fire the status/error/result signals Android
/// would send.
class FakeSpeechToText extends stt.SpeechToText {
  FakeSpeechToText() : super.withMethodChannel();

  stt.SpeechErrorListener? _onError;
  stt.SpeechStatusListener? _onStatus;
  stt.SpeechResultListener? _onResult;
  int listenCount = 0;
  bool stopped = false;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = stt.SpeechToText.defaultFinalTimeout,
    List<stt.SpeechConfigOption>? options,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    return true;
  }

  @override
  Future<List<stt.LocaleName>> locales() async => [];

  @override
  Future listen({
    stt.SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    _onResult = onResult;
    listenCount++;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> stop() async => stopped = true;

  void sendStatus(String status) => _onStatus?.call(status);
  void sendError(String code) => _onError?.call(SpeechRecognitionError(code, false));
  void sendResult(String words, {required bool isFinal}) => _onResult?.call(
    SpeechRecognitionResult(
      [SpeechRecognitionWords(words, null, 1)],
      isFinal ? ResultType.finalResult.value : ResultType.partial.value,
    ),
  );
}

void main() {
  late FakeSpeechToText fake;
  late OnDeviceSpeechProvider provider;
  late List<(String, bool)> results;
  late List<String> errors;

  /// Starts a session and lets it settle, all inside [async]'s fake clock.
  void start(FakeAsync async) {
    provider.startListening(
      localeCode: 'en-US',
      onResult: (t, f) => results.add((t, f)),
      onError: errors.add,
    );
    async.flushMicrotasks();
  }

  /// Advances past a normal silence timeout, so the session reads as healthy.
  void speakLong(FakeAsync async) => async.elapse(const Duration(seconds: 3));

  setUp(() {
    fake = FakeSpeechToText();
    provider = OnDeviceSpeechProvider(fake);
    results = [];
    errors = [];
  });

  test('a bare "done" status with no result or error restarts the mic', () {
    fakeAsync((async) {
      start(async);
      expect(fake.listenCount, 1);

      speakLong(async);
      fake.sendStatus(stt.SpeechToText.doneStatus);
      async.elapse(const Duration(seconds: 1));

      expect(fake.listenCount, 2, reason: 'silent session end must not kill the mic');
      expect(errors, isEmpty);
    });
  });

  test('a long silence — many restarts in a row — never switches the mic off', () {
    fakeAsync((async) {
      start(async);
      // Two minutes of someone thinking: ~40 silence timeouts back to back.
      for (var i = 0; i < 40; i++) {
        speakLong(async);
        fake.sendError('error_no_match');
        async.elapse(const Duration(seconds: 1));
      }
      expect(fake.listenCount, 41);
      expect(errors, isEmpty, reason: 'pausing to think must not stop the mic');
    });
  });

  test('transient busy/client errors during a restart are retried, not fatal', () {
    fakeAsync((async) {
      start(async);
      speakLong(async);
      fake.sendError('error_busy');
      async.elapse(const Duration(seconds: 1));
      speakLong(async);
      fake.sendError('error_client');
      async.elapse(const Duration(seconds: 1));

      expect(fake.listenCount, 3);
      expect(errors, isEmpty);
    });
  });

  test('a permanent error stops immediately with a clear message', () {
    fakeAsync((async) {
      start(async);
      fake.sendError('error_insufficient_permissions');
      async.elapse(const Duration(seconds: 1));

      expect(fake.listenCount, 1, reason: 'retrying a permission error is pointless');
      expect(errors.single, contains('Microphone permission'));
    });
  });

  test('a recognizer that refuses to run gives up instead of looping forever', () {
    fakeAsync((async) {
      start(async);
      // Each session dies instantly — no time passes before the next error.
      for (var i = 0; i < 20; i++) {
        fake.sendError('error_client');
        async.elapse(const Duration(milliseconds: 200));
      }

      expect(errors, hasLength(1), reason: 'should stop and report exactly once');
      // The real cause is surfaced, not a generic message.
      expect(errors.single, contains('speech recognizer rejected'));
      expect(fake.listenCount, lessThan(10));
    });
  });

  test('tapping stop ends the session and suppresses trailing noise', () {
    fakeAsync((async) {
      start(async);
      provider.stopListening();
      async.flushMicrotasks();
      expect(fake.stopped, isTrue);

      // What Android typically sends after a stop with nothing said.
      fake.sendError('error_no_match');
      fake.sendStatus(stt.SpeechToText.doneStatus);
      async.elapse(const Duration(seconds: 1));

      expect(fake.listenCount, 1, reason: 'a stopped mic must stay stopped');
      expect(errors, isEmpty, reason: 'no scary error for an empty recording');
    });
  });

  test('text from each chunk is kept across restarts', () {
    fakeAsync((async) {
      start(async);
      fake.sendResult('hello there', isFinal: true);
      async.elapse(const Duration(seconds: 1));
      fake.sendResult('how are you', isFinal: false);
      async.flushMicrotasks();

      expect(fake.listenCount, 2);
      expect(results.last, ('hello there how are you', false));
    });
  });

  test('stopping after speech delivers the full transcript as final', () {
    fakeAsync((async) {
      start(async);
      fake.sendResult('first part', isFinal: true);
      async.elapse(const Duration(seconds: 1));

      provider.stopListening();
      async.flushMicrotasks();
      fake.sendResult('second part', isFinal: true);
      async.flushMicrotasks();

      expect(results.last, ('first part second part', true));
    });
  });
}
