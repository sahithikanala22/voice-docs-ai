import 'dart:async';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePaths extends PathProviderPlatform {
  FakePaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class FakeSpeech implements SpeechRepository {
  void Function(String, bool)? result;
  void Function(String)? error;
  Future<void> Function()? whenStopped;
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  @override
  bool isListening = false;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String, bool) onResult,
    required void Function(double) onSoundLevel,
    required void Function(String) onError,
  }) async {
    starts++;
    isListening = true;
    result = onResult;
    error = onError;
  }

  @override
  Future<void> stopListening() async {
    stops++;
    isListening = false;
    if (whenStopped != null) {
      await whenStopped!();
    } else {
      result?.call('final words', true);
    }
  }

  @override
  Future<void> cancel() async {
    cancels++;
    isListening = false;
  }
}
