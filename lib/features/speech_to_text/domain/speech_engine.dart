/// Which backend transcribes speech.
enum SpeechEngine {
  /// Free OS recognition service; offline availability depends on device settings — the default. Reliability depends on
  /// the phone's own OS/OEM speech recognizer.
  onDevice,

  /// Local multilingual Whisper inference using a verified downloaded model.
  whisper,

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

extension SpeechEnginePrivacy on SpeechEngine {
  String get label => switch (this) {
    SpeechEngine.onDevice => 'Device speech',
    SpeechEngine.whisper => 'Whisper — Free Offline',
    SpeechEngine.googleCloud => 'Google Cloud',
  };
  String get privacyDescription => switch (this) {
    SpeechEngine.whisper =>
      'Whisper — Free Offline: download the multilingual base model once in Settings. Recording and transcription then stay on this device, with no API key or cloud fallback. Text appears after Stop. Audio remains in Saved recordings until you delete it.',
    SpeechEngine.onDevice =>
      'Device speech recognition: your phone\'s speech service processes audio. It may use the internet or send audio to its provider; offline support depends on downloaded languages and device settings.',
    SpeechEngine.googleCloud =>
      'Google Cloud speech: audio is saved on this device before upload. Transcription uses requests of at most 54 seconds; internet and an API key are required and charges may apply. Audio stays in Recover recordings until you delete it.',
  };
}
