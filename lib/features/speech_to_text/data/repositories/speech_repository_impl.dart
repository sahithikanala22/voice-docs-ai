import '../../domain/speech_repository.dart';
import '../providers/speech_provider.dart';
import '../../domain/recording_phase.dart';

class SpeechRepositoryImpl
    implements
        SpeechRepository,
        SavedRecordingAcknowledgement,
        RecordingStatusSource,
        RecordingContextSink,
        CancelableTranscription {
  SpeechRepositoryImpl(this._provider);

  final SpeechProvider _provider;
  @override
  void cancelTranscription() {
    if (_provider is CancelableTranscription) {
      (_provider as CancelableTranscription).cancelTranscription();
    }
  }

  @override
  Stream<RecordingProgress> get recordingProgress =>
      _provider is RecordingStatusSource
      ? (_provider as RecordingStatusSource).recordingProgress
      : const Stream.empty();
  @override
  String? get recordingId => _provider is RecordingStatusSource
      ? (_provider as RecordingStatusSource).recordingId
      : null;
  @override
  void setRecordingContext({DateTime? entryDate, String? folderId}) {
    if (_provider is RecordingContextSink) {
      (_provider as RecordingContextSink).setRecordingContext(
        entryDate: entryDate,
        folderId: folderId,
      );
    }
  }

  @override
  Future<void> confirmSaved() async {
    final provider = _provider;
    if (provider is SavedRecordingAcknowledgement) {
      await (provider as SavedRecordingAcknowledgement).confirmSaved();
    }
  }

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
