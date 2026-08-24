import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(AppConstants.defaultSourceLanguageCode) String sourceLanguageCode,
    @Default(true) bool hapticFeedback,
    /// The folder new voice entries currently save into, chosen via the
    /// folder selector on the Voice screen. Null means unfiled.
    String? currentFolderId,
    /// Opt-in to theming from the device wallpaper (Material You) instead of
    /// the app's own brand color — off by default, see `AppTheme.light`.
    @Default(false) bool useDynamicColor,
    /// Which backend transcribes speech — see [SpeechEngine].
    @Default(SpeechEngine.onDevice) SpeechEngine speechEngine,
    /// User-supplied Google Cloud Speech-to-Text API key, only used when
    /// [speechEngine] is [SpeechEngine.googleCloud]. Stored locally
    /// (SharedPreferences) only — never bundled in the app or committed to
    /// source, so it can't leak via the APK or the repo.
    String? googleCloudApiKey,
    /// The chosen text-to-speech voice name per language code — a language
    /// with no entry just uses the device's default voice for that
    /// language. Keyed by `Language.code` (not the region-qualified locale)
    /// since that's what every "speak" call already has on hand.
    @Default(<String, String>{}) Map<String, String> ttsVoiceByLanguage,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
