import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

import 'diary_entry.dart';

/// Persists the diary as one JSON-encoded list under a single
/// SharedPreferences key, the same way history and folders are stored. Photos
/// are not in here — only their file names; the files live on disk.
class DiaryLocalDataSource {
  DiaryLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Newest day first; entries on the same day by most recently written.
  List<DiaryEntry> readAll() {
    final raw = _prefs.getString(PrefsKeys.diary);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList()
        ..sort(_newestFirst);
    } catch (_) {
      throw const StorageException('Saved diary entries could not be read.');
    }
  }

  Future<void> writeAll(List<DiaryEntry> entries) async {
    await _prefs.setString(PrefsKeys.diary, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static int _newestFirst(DiaryEntry a, DiaryEntry b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  }
}
