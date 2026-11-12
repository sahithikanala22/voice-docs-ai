import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_voice_docs/core/utils/language_key.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/theme/paper_style.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';

import '../../data/settings_local_datasource.dart';
import '../../data/settings_repository_impl.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(SettingsLocalDataSource(prefs));
});

/// The single source of truth for user preferences. Every mutator persists
/// immediately so settings survive an app restart with no explicit "save"
/// step.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> _writes = Future.value();
  Future<void> _update(AppSettings Function(AppSettings) transform) {
    final result = _writes.then((_) async {
      final current = state.value ?? await future;
      final updated = transform(current);
      await ref.read(settingsRepositoryProvider).save(updated);
      state = AsyncData(updated);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update((s) => s.copyWith(themeMode: mode));

  Future<void> setSourceLanguage(String code) =>
      _update((s) => s.copyWith(sourceLanguageCode: code));

  Future<void> setHapticFeedback(bool value) =>
      _update((s) => s.copyWith(hapticFeedback: value));

  Future<void> setCurrentFolderId(String? folderId) =>
      _update((s) => s.copyWith(currentFolderId: folderId));

  Future<void> setUseDynamicColor(bool value) =>
      _update((s) => s.copyWith(useDynamicColor: value));

  Future<void> setBiometricUnlockEnabled(bool value) =>
      _update((s) => s.copyWith(biometricUnlockEnabled: value));

  /// Pass null to go back to the app's default brand color.
  Future<void> setAccentColor(Color? color) =>
      _update((s) => s.copyWith(accentColorValue: color?.toARGB32()));

  Future<void> setPaperStyle(PaperStyle style) =>
      _update((s) => s.copyWith(paperStyle: style));

  /// Pass null to clear the saved photo (e.g. when switching away from
  /// [PaperStyle.customImage] entirely).
  Future<void> setCustomBackgroundPath(String? path) =>
      _update((s) => s.copyWith(customBackgroundPath: path));

  /// Pass null to go back to the app's default typeface.
  Future<void> setFontFamily(String? family) =>
      _update((s) => s.copyWith(fontFamily: family));

  Future<void> setSpeechEngine(SpeechEngine engine) =>
      _update((s) => s.copyWith(speechEngine: engine));

  Future<void> setGoogleCloudApiKey(String? apiKey) =>
      _update((s) => s.copyWith(googleCloudApiKey: apiKey));

  /// Sets (or, passing null, clears back to the device default) the
  /// preferred TTS voice for [languageCode].
  Future<void> setTtsVoice(String languageCode, String? voiceName) =>
      _update((s) {
        final voices = Map<String, String>.from(s.ttsVoiceByLanguage);
        voices.removeWhere(
          (key, _) => languageKey(key) == languageKey(languageCode),
        );
        if (voiceName == null) {
          voices.remove(languageCode);
        } else {
          voices[languageKey(languageCode)] = voiceName;
        }
        return s.copyWith(ttsVoiceByLanguage: voices);
      });
}
