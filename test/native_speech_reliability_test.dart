import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/on_device_speech_provider.dart';

class NativeFake implements stt.SpeechToText {
  void Function(SpeechRecognitionResult)? result;
  void Function(SpeechRecognitionError)? error;
  void Function(String)? status;
  int listens = 0;
  bool listening = false;
  @override
  set errorListener(void Function(SpeechRecognitionError)? listener) =>
      error = listener;
  @override
  set statusListener(void Function(String)? listener) => status = listener;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      error =
          invocation.namedArguments[#onError]
              as void Function(SpeechRecognitionError)?;
      status = invocation.namedArguments[#onStatus] as void Function(String)?;
      return Future<bool>.value(true);
    }
    if (invocation.memberName == #locales) {
      return Future<List<stt.LocaleName>>.value([]);
    }
    if (invocation.memberName == #listen) {
      result =
          invocation.namedArguments[#onResult]
              as void Function(SpeechRecognitionResult)?;
      listens++;
      listening = true;
      return Future<void>.value();
    }
    if (invocation.memberName == #stop || invocation.memberName == #cancel) {
      listening = false;
      return Future<void>.value();
    }
    if (invocation.memberName == #isListening) return listening;
    return super.noSuchMethod(invocation);
  }
}

SpeechRecognitionResult words(String value, {bool finalResult = true}) =>
    SpeechRecognitionResult.init([
      SpeechRecognitionWords(value, null, 1),
    ], finalResult ? ResultType.finalResult : ResultType.partial);

class _MemorySettings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings();

  void replace(AppSettings settings) => state = AsyncData(settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unrelated settings keep the recorder; engine changes replace it',
    () async {
      final container = ProviderContainer(
        overrides: [
          settingsControllerProvider.overrideWith(_MemorySettings.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);
      final original = container.read(speechProviderImplProvider);
      final settings =
          container.read(settingsControllerProvider.notifier)
              as _MemorySettings;
      settings.replace(
        const AppSettings(sourceLanguageCode: 'te', currentFolderId: 'work'),
      );
      expect(container.read(speechProviderImplProvider), same(original));
      settings.replace(
        const AppSettings(speechEngine: SpeechEngine.googleCloud),
      );
      expect(container.read(speechProviderImplProvider), isNot(same(original)));
    },
  );

  group('real speech plugin lifecycle', () {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'locales') return <String>[];
            return true;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'slow partial results do not stop the mic after two seconds',
      () async {
        final speech = stt.SpeechToText.withMethodChannel();
        final provider = OnDeviceSpeechProvider(speech: speech);
        try {
          await provider.startListening(
            localeCode: 'en-US',
            onResult: (_, _) {},
            onError: fail,
          );
          speech.statusListener!('listening');
          await Future<void>.delayed(const Duration(milliseconds: 2200));
          expect(calls.where((call) => call == 'stop'), isEmpty);
        } finally {
          await provider.cancel();
        }
      },
    );

    testWidgets(
      'a replacement provider receives completion and error callbacks',
      (tester) async {
        final speech = stt.SpeechToText.withMethodChannel();
        final old = OnDeviceSpeechProvider(speech: speech);
        await old.startListening(
          localeCode: 'en-US',
          onResult: (_, _) {},
          onError: fail,
        );
        await old.cancel();
        final errors = <String>[];
        final current = OnDeviceSpeechProvider(
          speech: speech,
          restartDelay: const Duration(milliseconds: 1),
        );
        try {
          await current.initialize();
          await current.startListening(
            localeCode: 'en-US',
            onResult: (_, _) {},
            onError: errors.add,
          );
          speech.statusListener!('done');
          await tester.pump(const Duration(milliseconds: 20));
          expect(calls.where((call) => call == 'listen'), hasLength(3));
          expect(calls.where((call) => call == 'initialize'), hasLength(1));
          speech.errorListener!(
            SpeechRecognitionError('error_permission', true),
          );
          expect(errors.single, contains('Microphone permission'));
        } finally {
          await current.cancel();
        }
      },
    );
  });

  testWidgets(
    'duplicate finals and stale callbacks cannot duplicate transcript segments',
    (tester) async {
      final native = NativeFake();
      final text = <String>[];
      final provider = OnDeviceSpeechProvider(
        speech: native,
        restartDelay: const Duration(milliseconds: 1),
      );
      await provider.startListening(
        localeCode: 'te-IN',
        onResult: (s, _) => text.add(s),
        onError: fail,
      );
      final old = native.result!;
      old(words('first'));
      old(words('first'));
      expect(text, ['first']);
      await tester.pump(const Duration(milliseconds: 10));
      old(words('stale duplicate'));
      native.result!(words('second', finalResult: false));
      expect(text.last, 'first second');
      await provider.stopListening();
      native.result!(words('second final'));
      expect(text.last, 'first second final');
      await provider.cancel();
      final count = text.length;
      old(words('after dispose'));
      expect(text.length, count);
    },
  );
  testWidgets('a partial segment is preserved before a no-match restart', (
    tester,
  ) async {
    final native = NativeFake();
    final text = <String>[];
    final provider = OnDeviceSpeechProvider(
      speech: native,
      restartDelay: const Duration(milliseconds: 1),
    );
    await provider.startListening(
      localeCode: 'en-US',
      onResult: (s, _) => text.add(s),
      onError: fail,
    );
    native.result!(words('before pause', finalResult: false));
    native.error!(SpeechRecognitionError('error_no_match', false));
    await tester.pump(const Duration(milliseconds: 10));
    native.result!(words('after pause'));
    expect(text.last, 'before pause after pause');
    await provider.cancel();
  });
  testWidgets(
    'empty recognition failures have bounded restarts and cancel pending timers',
    (tester) async {
      final native = NativeFake();
      final errors = <String>[];
      final provider = OnDeviceSpeechProvider(
        speech: native,
        restartDelay: const Duration(milliseconds: 1),
        maxEmptyRestarts: 2,
      );
      await provider.startListening(
        localeCode: 'en-US',
        onResult: (_, _) {},
        onError: errors.add,
      );
      for (var i = 0; i < 5; i++) {
        native.error!(SpeechRecognitionError('error_speech_timeout', false));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(errors, hasLength(1));
      expect(errors.single, contains('repeatedly ended'));
      expect(native.listens, 3);
      await provider.cancel();
      final count = native.listens;
      await tester.pump(const Duration(milliseconds: 30));
      expect(native.listens, count);
    },
  );
}
