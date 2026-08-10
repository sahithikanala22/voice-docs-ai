import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

import 'history_item.dart';

/// Persists history as a single JSON-encoded list under one SharedPreferences
/// key — plenty for a bounded, locally-scoped list like this; a real
/// database would be overkill.
class HistoryLocalDataSource {
  HistoryLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<HistoryItem> readAll() {
    final raw = _prefs.getString(PrefsKeys.history);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      throw const StorageException('Saved history could not be read.');
    }
  }

  Future<void> writeAll(List<HistoryItem> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(PrefsKeys.history, encoded);
  }
}
