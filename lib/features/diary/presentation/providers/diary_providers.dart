import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import '../../data/diary_entry.dart';

final diaryControllerProvider =
    AsyncNotifierProvider<DiaryController, List<DiaryEntry>>(
      DiaryController.new,
    );

class DiaryController extends AsyncNotifier<List<DiaryEntry>> {
  Future<void> _writes = Future.value();
  PrivateStore get _store => PrivateStore(ref.read(sharedPreferencesProvider));

  @override
  Future<List<DiaryEntry>> build() async {
    final raw = await _store.read(PrefsKeys.diary);
    if (raw == null || raw.isEmpty) return [];
    final entries = (jsonDecode(raw) as List)
        .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return _sort(entries);
  }

  List<DiaryEntry> _sort(List<DiaryEntry> entries) => entries
    ..sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date == 0 ? b.updatedAt.compareTo(a.updatedAt) : date;
    });

  Future<void> _mutate(void Function(List<DiaryEntry>) change) {
    final operation = _writes.then((_) async {
      final current = List<DiaryEntry>.of(state.value ?? await future);
      change(current);
      _sort(current);
      await _store.write(
        PrefsKeys.diary,
        jsonEncode(current.map((e) => e.toJson()).toList()),
      );
      state = AsyncData(current);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> save(DiaryEntry entry) => _mutate((entries) {
    if (entry.isBlank) return;
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
  });
  Future<void> delete(String id) =>
      _mutate((entries) => entries.removeWhere((e) => e.id == id));
}

final diaryPhotoStoreProvider = Provider<DiaryPhotoStore>(
  (ref) => DiaryPhotoStore(),
);

class DiaryPhotoStore {
  Future<Directory> _directory() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/diary_photos',
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> import(String sourcePath) async {
    final dir = await _directory();
    final extension = sourcePath.split('.').last.toLowerCase();
    final safeExtension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : 'jpg';
    return (await File(sourcePath).copy(
      '${dir.path}/diary_${DateTime.now().microsecondsSinceEpoch}.$safeExtension',
    )).path;
  }

  Future<void> remove(Iterable<String> paths) async {
    if (paths.isEmpty) return;
    final root = (await _directory()).absolute.path.replaceAll('\\', '/');
    for (final path in paths) {
      final file = File(path);
      final normalized = file.absolute.path.replaceAll('\\', '/');
      // Never delete paths supplied by an import outside this feature's store.
      if (normalized.startsWith('$root/') &&
          !normalized.contains('/../') &&
          await file.exists()) {
        await file.delete();
      }
    }
  }
}
