import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'speech_provider.dart';
import '../pending_recording_store.dart';
import '../../domain/speech_repository.dart';
import '../../domain/recording_phase.dart';

/// One durable microphone capture implementation, independent of transcription.
abstract class DurableRecordingProvider
    implements
        SpeechProvider,
        SavedRecordingAcknowledgement,
        RecordingStatusSource,
        RecordingContextSink,
        CancelableTranscription {
  DurableRecordingProvider({
    this.recoveryStore,
    AudioRecorder? recorder,
    this.transcribeOnStop = true,
  }) : _captureRecorder = recorder,
       _injectedRecorder = recorder != null;
  final bool transcribeOnStop;
  Future<void> validateStart() async {}
  String get transcriptionFailureMessage =>
      'Offline transcription failed. Audio is kept in Recover recordings. Check the model and free storage, then retry.';
  final bool _injectedRecorder;
  AudioRecorder? _captureRecorder;
  AudioRecorder get _recorder => _captureRecorder ??= AudioRecorder();
  PendingRecordingStore? recoveryStore;
  Future<PendingRecordingStore> get recovery async =>
      recoveryStore ??= await PendingRecordingStore.open();
  final _progress = StreamController<RecordingProgress>.broadcast(sync: true);
  @override
  Stream<RecordingProgress> get recordingProgress => _progress.stream;
  @override
  String? get recordingId => _pendingId;
  String? _pendingId;
  DateTime? _entryDate;
  String? _folderId;
  void Function(String, bool)? _onResult;
  void Function(String)? _onError;
  bool _isListening = false,
      _stopRequested = false,
      _interrupted = false,
      _captureAttempted = false,
      _captureFinished = false;
  Completer<void>? _starting;
  Future<void>? _stopping;
  StreamSubscription<Amplitude>? _amplitude;
  StreamSubscription<RecordState>? _nativeState;
  final _interruptions = <StreamSubscription<dynamic>>[];
  Timer? _watchdog;
  bool _checkingSize = false;
  CancelToken cancellation = CancelToken();
  static const bytesPerSecond = 32000;
  @override
  void setRecordingContext({DateTime? entryDate, String? folderId}) {
    _entryDate = entryDate;
    _folderId = folderId;
  }

  void emitProgress(RecordingPhase phase, {bool saved = false, String? id}) {
    if (!_progress.isClosed) {
      _progress.add(
        RecordingProgress(phase, id: id ?? _pendingId, audioSaved: saved),
      );
    }
  }

  @override
  Future<bool> initialize() async => true;
  @override
  bool get isListening => _isListening;
  @override
  void cancelTranscription() =>
      cancellation.cancel('Transcription deferred; audio retained');
  @override
  Future<void> confirmSaved() async {
    final id = _pendingId;
    if (id != null) await (await recovery).markSaved(id);
  }

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String, bool) onResult,
    void Function(double)? onSoundLevel,
    required void Function(String) onError,
  }) async {
    if (_starting != null || _stopping != null || _isListening) return;
    _starting = Completer<void>();
    _onResult = onResult;
    _onError = onError;
    _pendingId = null;
    _stopRequested = false;
    _interrupted = false;
    _captureAttempted = false;
    _captureFinished = false;
    cancellation = CancelToken();
    emitProgress(RecordingPhase.preparing);
    var startFailed = false;
    try {
      await validateStart();
      if (!await _recorder.hasPermission()) {
        throw StateError(
          'Microphone permission is required. If permanently denied, enable it in system app settings.',
        );
      }
      if (_stopRequested) return;
      final store = await recovery;
      final item = await store.begin(
        localeCode,
        entryDate: _entryDate,
        folderId: _folderId,
      );
      _pendingId = item.id;
      if (_stopRequested) return;
      final path = await store.capturePath(item.id);
      _nativeState = _recorder.onStateChanged().listen(
        (state) {
          if (_isListening && !_stopRequested && state != RecordState.record) {
            interrupt(
              'Audio was interrupted or the microphone stopped. Captured audio is kept in Recover recordings.',
            );
          }
        },
        onError: (Object _) {
          interrupt(
            'Recording stopped unexpectedly. Check microphone access and free storage; captured bytes are kept.',
          );
        },
      );
      // A native start can acquire the microphone and then throw. Stop that
      // attempt too, even when start never returned successfully.
      _captureAttempted = true;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pause,
        ),
        path: path,
      );
      _isListening = true;
      if (!_injectedRecorder) {
        final session = await AudioSession.instance;
        _interruptions.add(
          session.interruptionEventStream.listen((event) {
            if (event.begin) {
              interrupt(
                'A call or another audio app interrupted capture. Audio is kept.',
              );
            }
          }),
        );
        _interruptions.add(
          session.becomingNoisyEventStream.listen((_) {
            interrupt(
              'The audio route changed. Capture stopped and audio is kept.',
            );
          }),
        );
        _interruptions.add(
          session.devicesChangedEventStream.listen((event) {
            if (event.devicesRemoved.isNotEmpty) {
              interrupt(
                'An audio device disconnected. Capture stopped and audio is kept.',
              );
            }
          }),
        );
      }
      await store.setPhase(item.id, RecordingPhase.recording);
      emitProgress(RecordingPhase.recording, saved: true);
      if (onSoundLevel != null) {
        _amplitude = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 150))
            .listen((a) {
              if (_isListening && !_stopRequested) {
                onSoundLevel(((a.current + 50) / 5).clamp(0.0, 10.0));
              }
            }, onError: (Object _) {});
      }
      _watchdog = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_checkingSize || !_isListening || _stopRequested) return;
        _checkingSize = true;
        try {
          if (await File(path).length() >=
              PendingRecordingStore.maxRecordingBytes) {
            interrupt(
              'Recording reached the 256 MiB safety limit. Captured audio is saved.',
            );
          }
        } catch (_) {
          interrupt(
            'Recording storage is unavailable. Captured audio has not been deleted.',
          );
        } finally {
          _checkingSize = false;
        }
      });
    } catch (error) {
      startFailed = true;
      _interrupted = true;
      emitProgress(RecordingPhase.failed, saved: _pendingId != null);
      onError(
        error is StateError
            ? error.message.toString()
            : 'Could not start recording. Check microphone access and free storage. Any captured audio is kept.',
      );
    } finally {
      _starting!.complete();
      _starting = null;
    }
    // Complete the start gate first: finalization waits for it. Providers must
    // release capture themselves, including when used without a coordinator.
    if (startFailed) await stopListening();
  }

  /// Calls, focus loss and route removal end capture; never auto-resume a mic.
  void interrupt(String message) {
    if (_stopRequested || (!_isListening && _starting == null)) return;
    _interrupted = true;
    _onError?.call(message);
    unawaited(stopListening());
  }

  @override
  Future<void> stopListening() {
    _stopRequested = true;
    return _stopping ??= _finishCapture().whenComplete(() => _stopping = null);
  }

  Future<void> _finishCapture() async {
    await _starting?.future;
    final id = _pendingId;
    if (id == null || _captureFinished) return;
    _captureFinished = true;
    final store = await recovery;
    _watchdog?.cancel();
    await _amplitude?.cancel();
    await _nativeState?.cancel();
    for (final subscription in _interruptions) {
      await subscription.cancel();
    }
    _interruptions.clear();
    _isListening = false;
    emitProgress(RecordingPhase.saving, saved: true);
    try {
      if (_captureAttempted) await _recorder.stop();
      await store.setPhase(id, RecordingPhase.saving);
      await store.sealCapture(id);
      final item = await store.get(id);
      if (item.byteLength == 0) {
        throw StateError(
          'No audio was captured. The empty recovery entry can be deleted.',
        );
      }
      if (_interrupted || cancellation.isCancelled || !transcribeOnStop) {
        final phase = _interrupted || cancellation.isCancelled
            ? RecordingPhase.interrupted
            : RecordingPhase.completed;
        await store.setPhase(id, phase);
        emitProgress(phase, saved: true);
        _onResult?.call('', true);
        return;
      }
      final text = await transcribeRetained(item, resetCancellation: false);
      _onResult?.call(text, true);
    } catch (error) {
      final phase = cancellation.isCancelled || _interrupted
          ? RecordingPhase.interrupted
          : RecordingPhase.failed;
      try {
        await store.setPhase(
          id,
          phase,
          error: error is StateError
              ? error.message.toString()
              : 'Transcription or final storage write did not finish. Retry after checking connection and storage.',
        );
      } catch (_) {}
      emitProgress(phase, saved: true);
      _onError?.call(
        error is StateError
            ? error.message.toString()
            : transcriptionFailureMessage,
      );
    }
  }

  @override
  Future<void> cancel() async {
    cancellation.cancel('Recording session ended');
    _stopRequested = true;
    await stopListening();
    _onResult = null;
    _onError = null;
    // AudioRecorder.cancel deletes its file: never use it for recoverable audio.
    if (!_injectedRecorder) {
      await _captureRecorder?.dispose();
      _captureRecorder = null;
    }
  }

  Future<String> transcribeRetained(
    PendingRecording recording, {
    bool resetCancellation = true,
  });
}

class AudioOnlyRecordingProvider extends DurableRecordingProvider {
  AudioOnlyRecordingProvider({super.recoveryStore, super.recorder})
    : super(transcribeOnStop: false);
  @override
  Future<String> transcribeRetained(
    PendingRecording recording, {
    bool resetCancellation = true,
  }) async {
    throw StateError('Choose a transcription engine in Recover recordings.');
  }
}
