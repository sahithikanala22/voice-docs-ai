import 'dart:async';
import 'recognition_state.dart';
import 'recording_phase.dart';
import 'speech_repository.dart';

typedef RecordingSaver = Future<void> Function(String transcript);

/// One owner serializes microphone sessions and keeps persistence independent
/// of mounted screens. Disposal stops and finalizes capture before releasing it.
class RecordingCoordinator {
  RecordingCoordinator({
    required this.repository,
    required this.requestPermission,
    this.finalResultTimeout = const Duration(seconds: 2),
  });
  final SpeechRepository Function() repository;
  final Future<bool> Function() requestPermission;
  final Duration finalResultTimeout;
  _Session? _active;
  Future<void> _starts = Future.value();
  final _pendingTags = <String>{};
  bool _disposed = false;
  int _requestEpoch = 0;
  String? get recordingId => _active?.repo is RecordingStatusSource
      ? (_active!.repo as RecordingStatusSource).recordingId
      : null;

  Future<void> start({
    required String tag,
    required String locale,
    required void Function(RecognitionState) onChanged,
    RecordingSaver? save,
    Duration? limit,
    DateTime? entryDate,
    String? folderId,
    SpeechRepository? repositoryOverride,
  }) {
    if (_disposed ||
        _pendingTags.contains(tag) ||
        (_active?.tag == tag && !_active!.finishing)) {
      return Future.value();
    }
    _pendingTags.add(tag);
    final epoch = _requestEpoch;
    final result = _starts
        .then(
          (_) => _start(
            tag,
            locale,
            onChanged,
            save,
            limit,
            epoch,
            entryDate,
            folderId,
            repositoryOverride,
          ),
        )
        .whenComplete(() => _pendingTags.remove(tag));
    _starts = result.catchError((Object _) {});
    return result;
  }

  Future<void> _start(
    String tag,
    String locale,
    void Function(RecognitionState) onChanged,
    RecordingSaver? save,
    Duration? limit,
    int epoch,
    DateTime? entryDate,
    String? folderId,
    SpeechRepository? override,
  ) async {
    if (_disposed || epoch != _requestEpoch) return;
    await _stopActive();
    if (_disposed || epoch != _requestEpoch) return;
    final s = _Session(tag, override ?? repository(), onChanged, save);
    _active = s;
    _emit(
      s,
      s.state.copyWith(phase: RecordingPhase.preparing, isProcessing: true),
    );
    if (s.repo is RecordingStatusSource) {
      s.progress = (s.repo as RecordingStatusSource).recordingProgress.listen((
        progress,
      ) {
        if (_active != s || s.completed) return;
        if (progress.phase == RecordingPhase.interrupted ||
            progress.phase == RecordingPhase.failed) {
          s.terminalPhase = progress.phase;
        }
        _emit(
          s,
          s.state.copyWith(
            phase: progress.phase,
            isListening: !s.finishing && progress.phase.microphoneActive,
            isProcessing: s.finishing || progress.phase.busy,
            audioSaved: progress.audioSaved,
            recordingId: progress.id,
          ),
        );
      });
    }
    try {
      if (!await requestPermission()) {
        _error(
          s,
          'Microphone access is required. Enable it in system app settings if permission was permanently denied.',
        );
        return;
      }
      if (_disposed || _active != s || s.finishing) return;
      if (!await s.repo.initialize()) {
        _error(
          s,
          'Speech recognition is unavailable. Use Record meeting to save audio without a recognizer.',
        );
        return;
      }
      if (_disposed || _active != s || s.finishing) return;
      if (s.repo is RecordingContextSink) {
        (s.repo as RecordingContextSink).setRecordingContext(
          entryDate: entryDate,
          folderId: folderId,
        );
      }
      s.started = true;
      try {
        await s.repo.startListening(
          localeCode: locale,
          onResult: (text, isFinal) {
            if (_active != s || s.completed || s.resultFinal) return;
            _emit(s, s.state.copyWith(transcript: text));
            if (isFinal) {
              s.resultFinal = true;
              if (!s.finalResult.isCompleted) s.finalResult.complete();
              if (!s.finishing) unawaited(_stopActive(tag: s.tag));
            }
          },
          onSoundLevel: (level) {
            if (_active == s && !s.completed && !s.finishing) {
              _emit(s, s.state.copyWith(soundLevel: level));
            }
          },
          onError: (message) => _error(s, message),
        );
      } finally {
        s.startFinished.complete();
      }
      if (_active == s && !s.finishing) {
        final listening = s.repo.isListening;
        _emit(
          s,
          s.state.copyWith(
            isListening: listening,
            isProcessing: false,
            isAvailable: true,
            phase: listening ? RecordingPhase.recording : s.state.phase,
          ),
        );
        if (limit != null) s.timer = Timer(limit, () => unawaited(stop()));
      }
    } catch (_) {
      _error(
        s,
        'Recording could not start. Any captured audio is kept for recovery.',
      );
    }
  }

  void _emit(_Session s, RecognitionState next) {
    s.state = next;
    if (!_disposed) s.onChanged(next);
  }

  void _error(_Session s, String message) {
    if (_active != s || s.completed) return;
    s.failed = true;
    _emit(s, s.state.copyWith(errorMessage: message));
    if (!s.finalResult.isCompleted) s.finalResult.complete();
    if (!s.finishing) unawaited(_stopActive(tag: s.tag));
  }

  Future<void> stop({String? tag, bool cancelTranscription = false}) {
    if (cancelTranscription && (tag == null || _active?.tag == tag)) {
      final repo = _active?.repo;
      if (repo is CancelableTranscription) {
        (repo as CancelableTranscription).cancelTranscription();
      }
    }
    if (tag == null || _active?.tag == tag || _pendingTags.contains(tag)) {
      _requestEpoch++;
    }
    return _stopActive(tag: tag);
  }

  Future<void> _stopActive({String? tag}) async {
    final s = _active;
    if (s == null || (tag != null && s.tag != tag)) return;
    if (s.finishing) return s.done.future;
    s.finishing = true;
    s.timer?.cancel();
    _emit(
      s,
      s.state.copyWith(
        isListening: false,
        isProcessing: true,
        phase: RecordingPhase.saving,
      ),
    );
    try {
      if (s.started) await s.startFinished.future;
      await s.repo.stopListening();
      if (s.started && !s.finalResult.isCompleted) {
        await s.finalResult.future.timeout(
          finalResultTimeout,
          onTimeout: () {},
        );
      }
      s.completed = true;
      await s.repo.cancel();
      final text = s.state.transcript.trim();
      if (text.isNotEmpty && s.save != null) {
        await s.save!(text);
        if (s.repo is SavedRecordingAcknowledgement) {
          await (s.repo as SavedRecordingAcknowledgement).confirmSaved();
        }
      }
    } catch (_) {
      s.failed = true;
      // A native stop failure still needs resource release; durable providers
      // implement cancel as stop-and-retain, never delete.
      try {
        await s.repo.cancel();
      } catch (_) {}
      final text = s.state.transcript.trim();
      if (!s.completed && text.isNotEmpty && s.save != null) {
        try {
          await s.save!(text);
        } catch (_) {}
      }
      _emit(
        s,
        s.state.copyWith(
          errorMessage:
              'Recording was interrupted or could not be saved. Check Recover recordings; available text is kept.',
        ),
      );
    } finally {
      s.completed = true;
      await s.progress?.cancel();
      _emit(
        s,
        s.state.copyWith(
          isListening: false,
          isProcessing: false,
          soundLevel: 0,
          phase:
              s.terminalPhase ??
              (s.failed
                  ? RecordingPhase.interrupted
                  : RecordingPhase.completed),
        ),
      );
      if (_active == s) _active = null;
      s.done.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requestEpoch++;
    final repo = _active?.repo;
    if (repo is CancelableTranscription) {
      (repo as CancelableTranscription).cancelTranscription();
    }
    unawaited(_stopActive());
  }
}

class _Session {
  _Session(this.tag, this.repo, this.onChanged, this.save);
  final String tag;
  final SpeechRepository repo;
  final void Function(RecognitionState) onChanged;
  final RecordingSaver? save;
  RecognitionState state = const RecognitionState();
  final finalResult = Completer<void>(),
      startFinished = Completer<void>(),
      done = Completer<void>();
  bool started = false,
      finishing = false,
      completed = false,
      failed = false,
      resultFinal = false;
  Timer? timer;
  RecordingPhase? terminalPhase;
  StreamSubscription<RecordingProgress>? progress;
}
