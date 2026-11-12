import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/theme/paper_style.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(ThemeMode.dark) ThemeMode themeMode,
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

    /// Stored in encrypted preferences with a device-protected encryption key.
    /// Excluded from all portable backups.
    String? googleCloudApiKey,

    /// The chosen text-to-speech voice name per language code — a language
    /// with no entry just uses the device's default voice for that
    /// language. Keyed by `Language.code` (not the region-qualified locale)
    /// since that's what every "speak" call already has on hand.
    @Default(<String, String>{}) Map<String, String> ttsVoiceByLanguage,

    /// Opt-in fingerprint/face unlock alongside the PIN, offered on the lock
    /// screen when the device actually has biometrics enrolled — off by
    /// default since it's an extra native permission/setup, not something
    /// every user needs.
    @Default(false) bool biometricUnlockEnabled,

    /// The ARGB value of the chosen accent color, or null to use the app's
    /// default brand indigo — stored as an int rather than a `Color` since
    /// freezed/json_serializable have no built-in `Color` codec. Ignored
    /// while [useDynamicColor] is on, same precedence as the brand default.
    int? accentColorValue,

    /// The background pattern shown behind every screen.
    @Default(PaperStyle.plain) PaperStyle paperStyle,

    /// An Android system font family name (e.g. `'serif'`, `'cursive'`), or
    /// null for the app's default typeface. Using Android's built-in family
    /// aliases instead of bundling font files keeps this free and fully
    /// offline — see `AppTheme.fontChoices`.
    String? fontFamily,

    /// Path to a copy of the user's chosen background photo, in the app's
    /// own documents directory — only rendered when [paperStyle] is
    /// [PaperStyle.customImage]. Same "copy it in, never trust the original
    /// URI" pattern as the profile picture, since a raw gallery URI can stop
    /// resolving after the app restarts or the source file moves.
    String? customBackgroundPath,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
