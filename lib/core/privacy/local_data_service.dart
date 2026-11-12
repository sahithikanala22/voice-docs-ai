import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';

/// Removes only known app-owned files; never follows imported paths or links.
class LocalDataService {
  LocalDataService({
    required this.prefs,
    required this.stopRecording,
    required this.cancelReminders,
    Future<Directory> Function()? documents,
    Future<Directory> Function()? temporary,
  }) : documents = documents ?? getApplicationDocumentsDirectory,
       temporary = temporary ?? getTemporaryDirectory;
  final SharedPreferences prefs;
  final Future<void> Function() stopRecording;
  final Future<void> Function() cancelReminders;
  final Future<Directory> Function() documents;
  final Future<Directory> Function() temporary;

  Future<void> deleteAll() async {
    await stopRecording();
    await cancelReminders();
    final root = await documents();
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (const {
          'diary_photos',
          'restored_images',
          'pending_cloud_recordings',
          'whisper_models',
          'profile_avatar.jpg',
          'custom_background.jpg',
          'auto_backup_before_reset.json',
        }.contains(name)) {
          await _deleteOwned(entity);
        }
      }
    }
    final temp = await temporary();
    if (await temp.exists()) {
      await for (final entity in temp.list(followLinks: false)) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name.startsWith('voicedocsai_') || name.startsWith('gcloud_stt_')) {
          await _deleteOwned(entity);
        }
      }
    }
    if (!await prefs.clear()) {
      throw StateError('Local settings could not be deleted.');
    }
    await PrivateStore(prefs).destroyKey();
  }

  Future<void> _deleteOwned(FileSystemEntity entity) async {
    if (entity is Directory) {
      // Walk without following symlinks, including links inside owned folders.
      await for (final child in entity.list(followLinks: false)) {
        await _deleteOwned(child);
      }
      await entity.delete();
    } else {
      await entity.delete();
    }
  }
}
