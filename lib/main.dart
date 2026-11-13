import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/services/notification_service.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_local_datasource.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_repository_impl.dart';

import 'app.dart';
import 'features/speech_to_text/data/pending_recording_store.dart';
import 'features/speech_to_text/data/providers/whisper_speech_provider.dart';
import 'features/speech_to_text/data/recording_playback_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  try {
    final recordings = await PendingRecordingStore.open();
    try {
      await recordings.importLegacyTemporary(await getTemporaryDirectory());
    } catch (_) {
      // Legacy import failure must not skip recovery of current recordings.
    }
    await recordings.recoverInterrupted();
  } catch (_) {
    // Preserve unreadable files; Recover recordings exposes a retryable error.
  }
  try {
    await WhisperSpeechProvider.cleanupScratch(await getTemporaryDirectory());
    await RecordingPlaybackController.cleanupScratch(
      await getTemporaryDirectory(),
    );
  } catch (_) {
    // A cache cleanup failure must not prevent access to durable recordings.
  }
  await NotificationService.instance.initialize();
  try {
    await _recoverAvatarPickLostToProcessDeath(sharedPreferences);
  } catch (_) {
    /* The lock gate presents storage failures without exposing content. */
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AiVoiceDocsApp(),
    ),
  );
}

/// Picking a profile picture via the camera can get the app's whole process
/// killed by the OS while the camera app is in the foreground (common on
/// RAM-constrained devices/OEM skins) — the in-flight `pickImage` call is
/// lost along with everything else. `retrieveLostData` recovers that photo
/// on the next cold start so it still reaches the profile instead of
/// silently vanishing, applied here (before the lock screen even loads)
/// since by the time the Profile screen could re-mount, the picture-taking
/// moment has already passed.
Future<void> _recoverAvatarPickLostToProcessDeath(
  SharedPreferences prefs,
) async {
  final LostDataResponse response;
  try {
    response = await ImagePicker().retrieveLostData();
  } catch (_) {
    return;
  }
  final pickedFile = response.file;
  if (pickedFile == null) return;

  final repository = AppLockRepositoryImpl(AppLockLocalDataSource(prefs));
  final account = await repository.load();
  if (account == null) return;

  final dir = await getApplicationDocumentsDirectory();
  final destFile = File('${dir.path}/profile_avatar.jpg');
  if (await destFile.exists()) await destFile.delete();
  await File(pickedFile.path).copy(destFile.path);
  await repository.save(account.copyWith(avatarPath: destFile.path));
}
