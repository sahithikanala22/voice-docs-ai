import 'package:ai_voice_docs/core/storage/private_store.dart';
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

  Future<List<Task>> readAll() async {
    final raw = await PrivateStore(_prefs).read(PrefsKeys.tasks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      throw const StorageException('Saved tasks could not be read.');
    }
  }

  Future<void> writeAll(List<Task> tasks) async {
    final encoded = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await PrivateStore(_prefs).write(PrefsKeys.tasks, encoded);
  }
}
