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
}
