import '../../domain/tts_repository.dart';
import '../providers/tts_provider.dart';

class TtsRepositoryImpl implements TtsRepository {
  TtsRepositoryImpl(this._provider);

  final TtsProvider _provider;

  @override
  Future<void> speak(String text, String languageCode) => _provider.speak(text, languageCode);

  @override
  Future<void> stop() => _provider.stop();

  @override
  void onStart(void Function() callback) => _provider.onStart(callback);

  @override
  void onComplete(void Function() callback) => _provider.onComplete(callback);

  @override
  void onError(void Function(String message) callback) => _provider.onError(callback);
}
