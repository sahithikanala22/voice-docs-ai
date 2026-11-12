import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

import '../domain/app_settings.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  Future<AppSettings> read() async {
    final raw = await PrivateStore(_prefs).read(PrefsKeys.settings);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const FormatException('Saved settings are invalid.');
    }
  }

  Future<void> write(AppSettings settings) async {
    await PrivateStore(
      _prefs,
    ).write(PrefsKeys.settings, jsonEncode(settings.toJson()));
  }
}
