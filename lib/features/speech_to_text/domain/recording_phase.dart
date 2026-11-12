enum RecordingPhase {
  idle,
  preparing,
  recording,
  paused,
  saving,
  transcribing,
  completed,
  interrupted,
  failed;

  bool get microphoneActive => this == recording;
  bool get busy => this == preparing || this == saving || this == transcribing;
}

class RecordingProgress {
  const RecordingProgress(this.phase, {this.id, this.audioSaved = false});
  final RecordingPhase phase;
  final String? id;
  final bool audioSaved;
}

abstract interface class RecordingStatusSource {
  Stream<RecordingProgress> get recordingProgress;
  String? get recordingId;
}

abstract interface class RecordingContextSink {
  void setRecordingContext({DateTime? entryDate, String? folderId});
}

abstract interface class CancelableTranscription {
  void cancelTranscription();
}
