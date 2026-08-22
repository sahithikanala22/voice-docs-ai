import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

/// All five SharedPreferences keys that hold a full JSON blob for a feature
/// — the complete set of on-device data a backup needs to cover. A new
/// feature that persists its own blob under a new `PrefsKeys` entry should
/// be added here too.
const _backupKeys = {
  'history': PrefsKeys.history,
  'settings': PrefsKeys.settings,
  'folders': PrefsKeys.folders,
  'appLockAccount': PrefsKeys.appLockAccount,
  'tasks': PrefsKeys.tasks,
};

const _backupFormatVersion = 1;

/// Exports/imports every locally-stored blob (history, folders, tasks,
/// settings, and the app-lock account/PIN) as one plain JSON file — the only
/// way to move data to a new phone or recover from a lost one, since nothing
/// in this app is backed by a server.
class BackupService {
  BackupService(this._prefs);

  final SharedPreferences _prefs;

  /// Writes a timestamped backup file to the temp dir and returns it, ready
  /// to hand to `share_plus` — same pattern as the PDF/Word exporters.
  Future<File> exportToFile() async {
    final data = {for (final entry in _backupKeys.entries) entry.key: _prefs.getString(entry.value)};

    final payload = {
      'app': AppConstants.appName,
      'formatVersion': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/voice_docs_ai_backup_$stamp.json');
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  /// Overwrites current local data with whatever a backup file holds. Only
  /// touches keys present (and non-null) in the file, so a backup taken
  /// before a feature existed simply leaves that feature's current data
  /// alone rather than wiping it.
  Future<void> importFromFile(File file) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const StorageException('That file is not a valid backup.');
    }

    final data = payload['data'];
    if (payload['app'] != AppConstants.appName || data is! Map) {
      throw const StorageException('That file is not a valid backup.');
    }

    for (final entry in _backupKeys.entries) {
      final value = data[entry.key];
      if (value is String) {
        await _prefs.setString(entry.value, value);
      }
    }
  }
}
