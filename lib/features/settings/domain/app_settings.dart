import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/theme/appearance.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
abstract class AppSettings with _$AppSettings {
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
    ///
    /// [JsonKey.unknownEnumValue] keeps an old saved value from a since
    /// removed engine (the app used to offer Google Cloud) from throwing on
    /// decode, which would otherwise reset every other setting to default.
    @JsonKey(unknownEnumValue: SpeechEngine.onDevice)
    @Default(SpeechEngine.onDevice)
    SpeechEngine speechEngine,
    /// User-supplied Sarvam AI API key, only used when [speechEngine] is
    /// [SpeechEngine.sarvam]. Stored locally (SharedPreferences) only —
    /// never bundled in the app or committed to source, so it can't leak via
    /// the APK or the repo.
    String? sarvamApiKey,
    /// The chosen text-to-speech voice name per language code — a language
    /// with no entry just uses the device's default voice for that
    /// language. Keyed by `Language.code` (not the region-qualified locale)
    /// since that's what every "speak" call already has on hand.
    @Default(<String, String>{}) Map<String, String> ttsVoiceByLanguage,
    /// Accent color family — ignored while [useDynamicColor] is on.
    @Default(AppPalette.indigo) AppPalette palette,
    /// Background texture behind every screen.
    @Default(PaperStyle.floatingDots) PaperStyle paperStyle,
    /// File name inside the app-background photo store (see
    /// `AppBackgroundPhotoStore`), not an absolute path. Only meaningful
    /// when [paperStyle] is [PaperStyle.customPhoto]; kept even if the style
    /// is switched away so switching back doesn't lose the picked photo.
    String? backgroundPhotoPath,
    /// Offer fingerprint/face unlock on the lock screen. The PIN always
    /// remains available as the fallback.
    @Default(false) bool biometricUnlock,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
