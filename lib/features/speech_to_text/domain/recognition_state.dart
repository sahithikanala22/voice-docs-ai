import 'package:freezed_annotation/freezed_annotation.dart';
import 'recording_phase.dart';

part 'recognition_state.freezed.dart';

/// Live state of a speech-recognition session, streamed to the UI in real
/// time while the user is speaking.
@freezed
abstract class RecognitionState with _$RecognitionState {
  const factory RecognitionState({
    @Default(false) bool isListening,
    @Default(false) bool isAvailable,
    @Default(false) bool isProcessing,
    @Default(RecordingPhase.idle) RecordingPhase phase,
    @Default(false) bool audioSaved,
    String? recordingId,
    @Default('') String transcript,
    @Default(0.0) double soundLevel,
    String? errorMessage,
  }) = _RecognitionState;
}
