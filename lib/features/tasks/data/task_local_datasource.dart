import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

import 'task.dart';

/// Persists tasks as a single JSON-encoded list under one SharedPreferences
/// key — same simplicity tradeoff as history/folders, a short checklist
/// doesn't need a real database.
class TaskLocalDataSource {
  TaskLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<Task> readAll() {
    final raw = _prefs.getString(PrefsKeys.tasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      throw const StorageException('Saved tasks could not be read.');
    }
  }

  Future<void> writeAll(List<Task> tasks) async {
    final encoded = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await _prefs.setString(PrefsKeys.tasks, encoded);
  }
}
