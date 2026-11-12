import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';

import 'app_lock_account.dart';

class AppLockLocalDataSource {
  AppLockLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  Future<AppLockAccount?> read() async {
    final raw = await PrivateStore(_prefs).read(PrefsKeys.appLockAccount);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppLockAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const FormatException('Saved app-lock account is invalid.');
    }
  }

  Future<void> write(AppLockAccount account) async {
    await PrivateStore(
      _prefs,
    ).write(PrefsKeys.appLockAccount, jsonEncode(account.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(PrefsKeys.appLockAccount);
  }
}
