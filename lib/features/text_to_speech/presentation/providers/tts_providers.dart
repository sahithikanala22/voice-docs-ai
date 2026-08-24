import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

import '../../data/providers/device_tts_provider.dart';
import '../../data/providers/tts_provider.dart';
import '../../data/repositories/tts_repository_impl.dart';
import '../../domain/tts_repository.dart';
import '../../domain/tts_voice_option.dart';

final ttsProviderImplProvider = Provider<TtsProvider>((ref) => DeviceTtsProvider());

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  return TtsRepositoryImpl(ref.watch(ttsProviderImplProvider));
});

/// Tracks whether the app is currently speaking, so UI (e.g. a speak button)
/// can show a stop icon instead while playback is in progress.
final ttsControllerProvider = NotifierProvider<TtsController, bool>(TtsController.new);

class TtsController extends Notifier<bool> {
  @override
  bool build() {
    final repo = ref.watch(ttsRepositoryProvider);
    repo.onStart(() => state = true);
    repo.onComplete(() => state = false);
    repo.onError((_) => state = false);
    return false;
  }

  Future<void> speak(String text, String languageCode) async {
    if (text.trim().isEmpty) return;
    final voiceName = ref.read(settingsControllerProvider).value?.ttsVoiceByLanguage[languageCode];
    await ref.read(ttsRepositoryProvider).speak(text, languageCode, voiceName: voiceName);
  }

  Future<void> stop() async {
    await ref.read(ttsRepositoryProvider).stop();
    state = false;
  }

  Future<List<TtsVoiceOption>> getVoices(String languageCode) =>
      ref.read(ttsRepositoryProvider).getVoices(languageCode);
}
