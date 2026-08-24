import '../../domain/tts_repository.dart';
import '../../domain/tts_voice_option.dart';
import '../providers/tts_provider.dart';

class TtsRepositoryImpl implements TtsRepository {
  TtsRepositoryImpl(this._provider);

  final TtsProvider _provider;

  @override
  Future<void> speak(String text, String languageCode, {String? voiceName}) =>
      _provider.speak(text, languageCode, voiceName: voiceName);

  @override
  Future<void> stop() => _provider.stop();

  @override
  Future<List<TtsVoiceOption>> getVoices(String languageCode) => _provider.getVoices(languageCode);

  @override
  void onStart(void Function() callback) => _provider.onStart(callback);

  @override
  void onComplete(void Function() callback) => _provider.onComplete(callback);

  @override
  void onError(void Function(String message) callback) => _provider.onError(callback);
}
