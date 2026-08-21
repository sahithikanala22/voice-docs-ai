import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

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
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
