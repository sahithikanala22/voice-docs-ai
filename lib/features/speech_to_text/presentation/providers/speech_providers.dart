import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

import '../../data/providers/google_cloud_speech_provider.dart';
import '../../data/providers/on_device_speech_provider.dart';
import '../../data/providers/speech_provider.dart';
import '../../data/repositories/speech_repository_impl.dart';
import '../../domain/recognition_state.dart';
import '../../domain/speech_engine.dart';
import '../../domain/speech_repository.dart';

/// Picks the active [SpeechProvider] from Settings' `speechEngine` choice —
/// [SpeechEngine.onDevice] (default, free, offline) or
/// [SpeechEngine.googleCloud] (needs an API key, see
/// [GoogleCloudSpeechProvider]'s doc comment for why it's batch-only rather
/// than live-streaming).
///
/// A Vosk-backed hybrid provider (`vosk_flutter_service`; offline, reliable
/// live captions for the languages it has a model for) was tried here and
/// fully reverted: on this device, the plugin's native Android side threw
/// `UnsatisfiedLinkError: Can't obtain peer field ID for class
/// com.sun.jna.Pointer` from a static initializer the moment the plugin was
/// registered — before any Dart code even ran — which crashed the app on
/// every launch, not just when speech recognition was used. That's a
/// JNA/ABI bootstrapping bug in the plugin's bundled native library for
/// this device's CPU architecture, not something fixable from the Dart or
/// Gradle side, and not avoidable by simply not calling into it from Dart —
/// the dependency itself had to come out.
final speechProviderImplProvider = Provider<SpeechProvider>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  if (settings?.speechEngine == SpeechEngine.googleCloud) {
    return GoogleCloudSpeechProvider(apiKey: settings?.googleCloudApiKey ?? '');
  }
  return OnDeviceSpeechProvider();
});

final speechRepositoryProvider = Provider<SpeechRepository>((ref) {
  return SpeechRepositoryImpl(ref.watch(speechProviderImplProvider));
});

/// Drives a single voice-to-text session: mic permission, live transcript
/// streaming, sound-level updates for the animated mic, and error surfacing.
///
/// Parameterized by [sessionTag] so each screen that embeds a mic (Home,
/// Translator) gets its own independent [RecognitionState] even though the
/// native recognizer underneath is a single shared singleton — otherwise,
/// because `StatefulShellRoute` keeps every tab alive, a single global
/// controller would leak one screen's live transcript into the other.
final speechControllerProvider =
    NotifierProvider.family<SpeechController, RecognitionState, String>(SpeechController.new);

class SpeechController extends FamilyNotifier<RecognitionState, String> {
  bool _isStarting = false;

  @override
  RecognitionState build(String sessionTag) {
    // Capture the repository now rather than re-reading it inside
    // onDispose: by teardown time the container may already be disposing
    // dependency providers, and ref.read would throw.
    final repo = ref.read(speechRepositoryProvider);
    ref.onDispose(repo.cancel);
    return const RecognitionState();
  }

  Future<void> startListening(String localeCode) async {
    // permission_handler throws PlatformException("A request for
    // permissions is already running...") if a second request fires while
    // one is in flight — guard re-entrancy here rather than trusting the UI
    // (a fast double-tap, or two screens sharing a mic, can race the
    // `state.isListening` flip that gates the caller).
    if (_isStarting || state.isListening) return;
    _isStarting = true;

    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        state = state.copyWith(
          errorMessage: 'Microphone permission is required to use voice input.',
        );
        return;
      }

      final repo = ref.read(speechRepositoryProvider);
      final available = await repo.initialize();
      if (!available) {
        state = state.copyWith(
          isAvailable: false,
          errorMessage: 'Speech recognition is not available on this device.',
        );
        return;
      }

      state = state.copyWith(
        isListening: true,
        isAvailable: true,
        errorMessage: null,
        transcript: '',
      );

      await repo.startListening(
        localeCode: localeCode,
        onResult: (transcript, isFinal) {
          state = state.copyWith(transcript: transcript, isListening: !isFinal);
        },
        onSoundLevel: (level) {
          state = state.copyWith(soundLevel: level);
        },
        onError: (message) {
          state = state.copyWith(isListening: false, errorMessage: message);
        },
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopListening() async {
    await ref.read(speechRepositoryProvider).stopListening();
    state = state.copyWith(isListening: false);
  }

  void clearTranscript() {
    state = state.copyWith(transcript: '', errorMessage: null);
  }

  void dismissError() {
    state = state.copyWith(errorMessage: null);
  }
}
