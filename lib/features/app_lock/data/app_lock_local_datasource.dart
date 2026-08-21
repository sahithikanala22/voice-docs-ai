import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

import 'app_lock_account.dart';

class AppLockLocalDataSource {
  AppLockLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  AppLockAccount? read() {
    final raw = _prefs.getString(PrefsKeys.appLockAccount);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppLockAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AppLockAccount account) async {
    await _prefs.setString(PrefsKeys.appLockAccount, jsonEncode(account.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(PrefsKeys.appLockAccount);
  }
}
