import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/providers/on_device_speech_provider.dart';
import '../../data/providers/speech_provider.dart';
import '../../data/repositories/speech_repository_impl.dart';
import '../../domain/recognition_state.dart';
import '../../domain/speech_repository.dart';

/// Swap this override to plug in a different [SpeechProvider] (e.g. the
/// cloud stub) without touching anything else in the feature.
final speechProviderImplProvider = Provider<SpeechProvider>((ref) => OnDeviceSpeechProvider());

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
