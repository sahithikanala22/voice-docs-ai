import '../../domain/speech_repository.dart';
import '../providers/speech_provider.dart';

class SpeechRepositoryImpl implements SpeechRepository {
  SpeechRepositoryImpl(this._provider);

  final SpeechProvider _provider;

  @override
  Future<bool> initialize() => _provider.initialize();

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    required void Function(String message) onError,
  }) {
    return _provider.startListening(
      localeCode: localeCode,
      onResult: onResult,
      onSoundLevel: onSoundLevel,
      onError: onError,
    );
  }

  @override
  Future<void> stopListening() => _provider.stopListening();

  @override
  Future<void> cancel() => _provider.cancel();

  @override
  bool get isListening => _provider.isListening;
}
