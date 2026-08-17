import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

import 'folder.dart';

/// Persists folders as a single JSON-encoded list under one SharedPreferences
/// key — same simplicity tradeoff as history, a bounded local list doesn't
/// need a real database.
class FolderLocalDataSource {
  FolderLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<Folder> readAll() {
    final raw = _prefs.getString(PrefsKeys.folders);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Folder.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      throw const StorageException('Saved folders could not be read.');
    }
  }

  Future<void> writeAll(List<Folder> folders) async {
    final encoded = jsonEncode(folders.map((e) => e.toJson()).toList());
    await _prefs.setString(PrefsKeys.folders, encoded);
  }
}
