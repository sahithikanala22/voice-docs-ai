import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';
import 'package:ai_voice_docs/core/utils/export_filename.dart';

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

  Map<String, dynamic> _buildPayload() {
    final data = {
      for (final entry in _backupKeys.entries)
        entry.key: _prefs.getString(entry.value),
    };
    return {
      'app': AppConstants.appName,
      'formatVersion': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
  }

  /// Writes a timestamped backup file to the temp dir and returns it, ready
  /// to hand to `share_plus` — same pattern as the PDF/Word exporters.
  Future<File> exportToFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voicedocsai_${exportFilenameStamp()}.json');
    await file.writeAsString(jsonEncode(_buildPayload()));
    return file;
  }

  /// Overwrites current local data with whatever a backup file holds. Only
  /// touches keys present (and non-null) in the file, so a backup taken
  /// before a feature existed simply leaves that feature's current data
  /// alone rather than wiping it.
  Future<void> importFromFile(File file) async {
    final payload = await _readPayload(file);
    await _applyPayload(payload, includeAccount: true);
  }

  Future<File> _autoBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    // Application-support storage, not the temp dir `exportToFile` uses —
    // this one needs to still be there after the app restarts, not just
    // long enough to hand off to a share sheet.
    return File('${dir.path}/auto_backup_before_reset.json');
  }

  /// Snapshots everything to a file in the app's own persistent storage
  /// right before a "Forgot PIN" reset wipes SharedPreferences —
  /// `SharedPreferences.clear()` only empties the prefs store, so a file
  /// written here survives that wipe and can be offered back once a new PIN
  /// is set up, instead of the reset meaning permanent data loss.
  Future<void> saveAutoBackupBeforeReset() async {
    final file = await _autoBackupFile();
    await file.writeAsString(jsonEncode(_buildPayload()));
  }

  Future<bool> hasAutoBackup() async {
    final file = await _autoBackupFile();
    return file.exists();
  }

  /// Restores history/folders/tasks/settings from the pre-reset snapshot —
  /// deliberately never the account/PIN blob, since the whole point of this
  /// path is getting back in with the *new* PIN just created, not silently
  /// reinstating the forgotten one.
  Future<void> restoreAutoBackupAfterReset() async {
    final file = await _autoBackupFile();
    if (!await file.exists()) return;
    final payload = await _readPayload(file);
    await _applyPayload(payload, includeAccount: false);
    await file.delete();
  }

  Future<Map<String, dynamic>> _readPayload(File file) async {
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
    return payload;
  }

  Future<void> _applyPayload(
    Map<String, dynamic> payload, {
    required bool includeAccount,
  }) async {
    final data = payload['data'] as Map;
    for (final entry in _backupKeys.entries) {
      if (!includeAccount && entry.key == 'appLockAccount') continue;
      final value = data[entry.key];
      if (value is String) {
        await _prefs.setString(entry.value, value);
      }
    }
  }
}
