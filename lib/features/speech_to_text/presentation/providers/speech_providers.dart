import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import '../../data/providers/google_cloud_speech_provider.dart';
import '../../data/providers/on_device_speech_provider.dart';
import '../../data/providers/durable_recording_provider.dart';
import '../../data/providers/whisper_speech_provider.dart';
import 'whisper_providers.dart';
import '../../data/providers/speech_provider.dart';
import '../../data/repositories/speech_repository_impl.dart';
import '../../domain/recognition_state.dart';
import '../../domain/recording_coordinator.dart';
import '../../domain/speech_engine.dart';
import '../../domain/speech_repository.dart';

final speechProviderImplProvider = Provider<SpeechProvider>((ref) {
  final (engine, apiKey) = ref.watch(
    settingsControllerProvider.select(
      (settings) =>
          (settings.value?.speechEngine, settings.value?.googleCloudApiKey),
    ),
  );
  if (engine == SpeechEngine.whisper) {
    return WhisperSpeechProvider(models: ref.watch(whisperModelStoreProvider));
  }
  if (engine == SpeechEngine.googleCloud) {
    return GoogleCloudSpeechProvider(apiKey: apiKey ?? '');
  }
  return OnDeviceSpeechProvider();
});

final speechRepositoryProvider = Provider<SpeechRepository>(
  (ref) => SpeechRepositoryImpl(ref.watch(speechProviderImplProvider)),
);

final meetingSpeechRepositoryProvider = Provider<SpeechRepository>(
  (ref) => SpeechRepositoryImpl(AudioOnlyRecordingProvider()),
);

final recordingCoordinatorProvider = Provider<RecordingCoordinator>((ref) {
  final coordinator = RecordingCoordinator(
    repository: () => ref.read(speechRepositoryProvider),
    requestPermission: () async {
      if (!(await Permission.microphone.request()).isGranted) return false;
      // Native speech requests its speech permission in initialize(); durable
      // audio-only capture does not require permission to a speech service.
      if (Platform.isAndroid) await Permission.bluetoothConnect.request();
      return true;
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Screens keep their own text; the coordinator alone owns the microphone.
final speechControllerProvider =
    NotifierProvider.family<SpeechController, RecognitionState, String>(
      SpeechController.new,
    );

class SpeechController extends FamilyNotifier<RecognitionState, String> {
  bool _disposed = false;
  bool _starting = false;
  @override
  RecognitionState build(String tag) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const RecognitionState();
  }

  Future<void> startListening(
    String localeCode, {
    String? languageCode,
    String? folderId,
    DateTime? timestamp,
    bool savedAudioOnly = false,
  }) async {
    if (_starting || state.isListening || state.isProcessing) return;
    _starting = true;
    try {
      final history = ref.read(historyControllerProvider.notifier);
      final owner = ref.read(recordingCoordinatorProvider);
      return await ref
          .read(recordingCoordinatorProvider)
          .start(
            tag: arg,
            locale: localeCode,
            entryDate: timestamp,
            folderId: folderId,
            repositoryOverride: savedAudioOnly
                ? ref.read(meetingSpeechRepositoryProvider)
                : null,
            onChanged: (next) {
              if (!_disposed) state = next;
            },
            save: arg == 'home'
                ? (text) {
                    final id = owner.recordingId;
                    return history.addEntry(
                      id == null
                          ? HistoryItem.voice(
                              text: text,
                              languageCode:
                                  languageCode ?? localeCode.split('-').first,
                              folderId: folderId,
                              timestamp: timestamp,
                            )
                          : HistoryItem(
                              id: 'recovered-cloud-$id',
                              sourceText: text,
                              sourceLanguageCode:
                                  languageCode ?? localeCode.split('-').first,
                              folderId: folderId,
                              timestamp: timestamp ?? DateTime.now(),
                            ),
                    );
                  }
                : null,
          );
    } finally {
      _starting = false;
    }
  }

  Future<void> stopListening() =>
      ref.read(recordingCoordinatorProvider).stop(tag: arg);
  void clearTranscript() {
    if (!state.isListening && !state.isProcessing) {
      state = state.copyWith(transcript: '', errorMessage: null);
    }
  }

  void dismissError() => state = state.copyWith(errorMessage: null);
}
