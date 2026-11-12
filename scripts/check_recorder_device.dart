// Diagnostic entrypoint. Records only short test captures; no transcription,
// account reads, PIN entry, or network uploads. Restore lib/main.dart afterward.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/pending_recording_store.dart';
import 'package:ai_voice_docs/features/speech_to_text/data/providers/google_cloud_speech_provider.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/recording_phase.dart';

void show(String text) => runApp(
  MaterialApp(
    home: Scaffold(body: Center(child: Text(text))),
  ),
);
Future<void> check(bool value, String message) async {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  show('Recorder diagnostic\nShort microphone captures; no uploads.');
  final store = await PendingRecordingStore.open();
  final marker = File(
    '${(await getApplicationDocumentsDirectory()).path}/recorder_probe_state.json',
  );
  try {
    if (await marker.exists()) {
      final state =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      final id = state['id'] as String;
      await store.recoverInterrupted();
      final item = await store.get(id);
      await check(
        item.phase == RecordingPhase.interrupted,
        'Interrupted status not restored',
      );
      await check(
        item.byteLength > 0,
        'No captured bytes survived process death',
      );
      await store.sealCapture(id);
      final wav = await store.exportWav(id, await getTemporaryDirectory());
      await check(
        await wav.length() == item.byteLength + 44,
        'Recovered WAV length mismatch',
      );
      debugPrint(
        'RECORDER_PROBE crash_recovery=PASS bytes=${item.byteLength} locale=${item.locale}',
      );
      await store.delete(id);
      await wav.delete();
      await marker.delete();
      show(
        'Recorder checks passed\nCapture, encryption, playback, WAV export, process recovery.',
      );
      debugPrint('RECORDER_PROBE ALL_PASS');
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 1));
    await check(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      'Keep the diagnostic visible and phone unlocked for capture.',
    );
    final capture = GoogleCloudSpeechProvider(
      apiKey: '',
      transcribeOnStop: false,
    );
    String? failure;
    await capture.startListening(
      localeCode: 'en-US',
      onResult: (_, _) {},
      onError: (e) => failure = e,
    );
    await check(
      failure == null && capture.isListening,
      'Native microphone start failed: $failure',
    );
    await Future<void>.delayed(const Duration(seconds: 5));
    await capture.stopListening();
    final id = capture.recordingId!;
    final item = await store.get(id);
    await check(
      item.byteLength > 0 && !capture.isListening,
      'Native capture not finalized',
    );
    final firstBytes = await store.readAudio(
      id,
      0,
      min(item.byteLength, PendingRecordingStore.maxReadBytes),
    );
    await check(firstBytes.isNotEmpty, 'Encrypted audio could not be read');
    await check(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      'The diagnostic left the foreground during capture; microphone signal cannot be validated.',
    );
    await check(
      firstBytes.any((value) => value != 0),
      'Capture contains only silence/zero samples; microphone signal not verified',
    );
    final wav = await store.exportWav(id, await getTemporaryDirectory());
    final player = AudioPlayer();
    try {
      await player.play(DeviceFileSource(wav.path, mimeType: 'audio/wav'));
      await check(
        player.state == PlayerState.playing,
        'Native WAV playback did not start',
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await player.stop();
    } finally {
      await player.dispose();
    }
    await capture.confirmSaved();
    await check(
      (await store.get(id)).byteLength == item.byteLength,
      'Acknowledgement discarded audio',
    );
    debugPrint(
      'RECORDER_PROBE capture_seal_playback_export=PASS bytes=${item.byteLength}',
    );
    await capture.cancel();
    await store.delete(id);
    await wav.delete();
    final interrupted = GoogleCloudSpeechProvider(
      apiKey: '',
      transcribeOnStop: false,
    );
    await interrupted.startListening(
      localeCode: 'te-IN',
      onResult: (_, _) {},
      onError: (e) => failure = e,
    );
    await check(
      interrupted.isListening,
      'Second capture did not start: $failure',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await marker.writeAsString(
      jsonEncode({'id': interrupted.recordingId}),
      flush: true,
    );
    show('Recorder diagnostic\nWaiting for controlled process termination.');
    debugPrint('RECORDER_PROBE READY_FOR_PROCESS_KILL');
    Timer(const Duration(seconds: 120), () {
      unawaited(interrupted.cancel());
    });
  } catch (error) {
    show('Recorder diagnostic failed\n$error');
    debugPrint('RECORDER_PROBE FAIL $error');
  }
}
