import 'package:freezed_annotation/freezed_annotation.dart';

part 'recognition_state.freezed.dart';

/// Live state of a speech-recognition session, streamed to the UI in real
/// time while the user is speaking.
@freezed
class RecognitionState with _$RecognitionState {
  const factory RecognitionState({
    @Default(false) bool isListening,
    @Default(false) bool isAvailable,
    @Default('') String transcript,
    @Default(0.0) double soundLevel,
    String? errorMessage,
  }) = _RecognitionState;
}
