import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:voxi_translate/core/constants/app_constants.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(AppConstants.defaultSourceLanguageCode) String sourceLanguageCode,
    @Default(AppConstants.defaultTargetLanguageCode) String targetLanguageCode,
    @Default(true) bool autoPlayTranslationTts,
    @Default(true) bool hapticFeedback,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
