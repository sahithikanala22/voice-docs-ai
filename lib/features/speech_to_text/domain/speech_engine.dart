/// Which backend transcribes speech.
enum SpeechEngine {
  /// Free, on-device, works offline — the default. Reliability depends on
  /// the phone's own OS/OEM speech recognizer.
  onDevice,

  /// Google Cloud Speech-to-Text's batch REST endpoint — needs an API key
  /// (Settings) and an internet connection, and bills per use past the free
  /// tier. Trades the on-device engine's live partial captions for a single,
  /// generally more accurate transcript delivered right after you stop
  /// talking (this is Google's batch `recognize` endpoint, not the
  /// streaming one — true live streaming needs OAuth/service-account
  /// credentials that can't safely ship in the app, so it's out of scope
  /// without a backend relay).
  googleCloud,
}
