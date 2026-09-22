/// Which backend transcribes speech.
enum SpeechEngine {
  /// Free, on-device, works offline — the default. Reliability depends on
  /// the phone's own OS/OEM speech recognizer.
  onDevice,

  /// Sarvam AI's speech-to-text REST endpoint — needs an API key (Settings)
  /// and an internet connection, and bills per use. Much stronger on Indian
  /// languages than a typical on-device recognizer, at the cost of the live
  /// partial captions: the transcript arrives right after you stop talking,
  /// because this is an upload-and-wait REST call rather than a streaming
  /// session.
  sarvam,

  /// OpenAI's Whisper model, running fully on-device via whisper.cpp
  /// (`whisper_ggml`). Free forever — no API key, no per-use billing — and
  /// works offline once its model file has been downloaded once. Generally
  /// more accurate than the OS recognizer, especially with accents, and
  /// unlike Sarvam it does stream live partial captions. Costs a one-time
  /// ~140MB download and noticeably more battery/CPU per recording than
  /// [onDevice].
  whisper,
}
