import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

import '../domain/app_settings.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  AppSettings read() {
    final raw = _prefs.getString(PrefsKeys.settings);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> write(AppSettings settings) async {
    await _prefs.setString(PrefsKeys.settings, jsonEncode(settings.toJson()));
  }
}
