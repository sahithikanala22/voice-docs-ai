import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_provider.dart';

/// Default [SpeechProvider]: wraps the `speech_to_text` plugin, which talks
/// to the native OS speech recognizer (Android `SpeechRecognizer`, iOS
/// `Speech` framework). Free, no API key, works offline where the OS engine
/// supports it.
///
/// Android's `SpeechRecognizer` ends a session after roughly 1-3 seconds of
/// silence — an OS-imposed limit the plugin can't override — which would
/// otherwise make the mic look like it "turns off" on every natural pause
/// mid-sentence. This class hides that by transparently re-listening
/// whenever a session ends on its own (not because the caller asked to
/// stop), stitching each chunk onto the running transcript so the caller
/// only ever sees one continuous session.
///
/// A session can end in three different ways, and all three have to be
/// caught or the mic dies mid-recording:
///
/// * a silence error (`error_no_match` / `error_speech_timeout`),
/// * a final result, or
/// * a bare `done` status carrying no result and no error at all — which is
///   what the recognizer reports when it gives up having heard nothing.
///
/// The last one is easy to miss precisely because nothing looks like a
/// failure: no error fires, no result arrives, the mic just stops.
///
/// Only an explicit [stopListening]/[cancel], or an error that genuinely can
/// never succeed on retry (no permission, unsupported language), ends the
/// caller's session — deliberately with no "give up after N failures" cap.
/// An earlier version had one, meant to protect against a stuck recognizer
/// spinning forever; in practice it was what made the mic cut itself off on
/// real devices, since a handful of restarts landing under the fast-failure
/// threshold (OS throttling a rapid rebind, a slow IPC round-trip, nothing
/// actually wrong) was enough to trip it. Retrying forever is the right
/// trade here: this only runs while the user is on the recording screen
/// looking at a Stop button, so a recognizer that's genuinely broken gets
/// noticed and stopped by hand in a few seconds either way.
class OnDeviceSpeechProvider implements SpeechProvider {
  /// Errors retrying can't fix — reported straight away. Everything else is
  /// retried, including the `error_busy` / `error_client` Android throws when
  /// a restart overlaps the previous session's teardown.
  static const _permanentErrors = {
    'error_insufficient_permissions',
    'error_permission',
    'error_language_not_supported',
    'error_language_unavailable',
  };

  /// Breathing room between restarts so a failure loop can't spin hot.
  static const _restartDelay = Duration(milliseconds: 150);

  OnDeviceSpeechProvider([stt.SpeechToText? speech]) : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool _initialized = false;
  List<stt.LocaleName> _deviceLocales = [];

  void Function(String transcript, bool isFinal)? _currentOnResult;
  void Function(double level)? _currentOnSoundLevel;
  void Function(String message)? _currentOnError;
  bool _stopRequested = false;

  /// Guards against several end-of-session signals (status, error, result)
  /// racing to restart the same session, and against the `cancel()` inside
  /// [_listenOnce] re-entering through its own status callback.
  bool _restarting = false;
  String _committedTranscript = '';
  String _activeLocaleId = '';

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: _handleNativeError,
      onStatus: _handleStatus,
    );
    if (_initialized) {
      _deviceLocales = await _speech.locales();
    }
    return _initialized;
  }

  /// The recognizer finished a session. When the caller hasn't asked to
  /// stop, that's the OS giving up on silence — keep the mic going.
  void _handleStatus(String status) {
    if (status == stt.SpeechToText.doneStatus) _restartUnlessStopped();
  }

  void _handleNativeError(SpeechRecognitionError error) {
    // Once the user has tapped stop, trailing errors are just teardown noise
    // (e.g. `error_no_match` for a recording with nothing said).
    if (_stopRequested) return;

    if (_permanentErrors.contains(error.errorMsg)) {
      _stopRequested = true;
      _currentOnError?.call(_friendlyError(error.errorMsg));
      return;
    }
    _restartUnlessStopped();
  }

  /// The single path every end-of-session signal funnels through, so the
  /// three of them can't stack up multiple overlapping restarts.
  Future<void> _restartUnlessStopped() async {
    if (_stopRequested || _restarting) return;

    _restarting = true;
    try {
      await Future<void>.delayed(_restartDelay);
      // Re-check: the user may have tapped stop during the delay.
      if (!_stopRequested) await _listenOnce();
    } finally {
      _restarting = false;
    }
  }

  /// Translates the plugin's raw Android `SpeechRecognizer` error codes (see
  /// https://developer.android.com/reference/android/speech/SpeechRecognizer)
  /// into actionable text. `error_client` in particular is Android's generic
  /// catch-all client error — on some heavily customized OEM ROMs it means
  /// there's no properly configured on-device recognition service (e.g. the
  /// Google app disabled or not set up) rather than anything this app can
  /// fix directly.
  String _friendlyError(String rawCode) {
    switch (rawCode) {
      case 'error_client':
        return "Your device's speech recognizer rejected the request. "
            'Make sure the Google app (or your device\'s speech recognition '
            'service) is installed, up to date, and enabled, then try again.';
      case 'error_network':
      case 'error_network_timeout':
        return 'A network error interrupted speech recognition.';
      case 'error_busy':
        return 'Speech recognition is busy — try again in a moment.';
      case 'error_insufficient_permissions':
      case 'error_permission':
        return 'Microphone permission is required to use voice input.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'This language is not supported by your device\'s speech recognizer.';
      default:
        return 'Speech recognition error: $rawCode';
    }
  }

  /// [appLanguageHint] is already a full, region-qualified locale (e.g.
  /// `en-US` — see `Language.localeHint`), since a bare code like `en` fails
  /// with `error_language_not_supported` / `error_language_unavailable` on
  /// Android. Some OEM ROMs' `locales()` implementations are unreliable
  /// (empty, or missing entries that the recognizer actually supports), so
  /// this only *upgrades* to an exact device-reported locale entry when one
  /// matches — it never downgrades to an unrelated device locale just
  /// because the hint wasn't found, since that would silently recognize in
  /// the wrong language.
  String _resolveLocaleId(String appLanguageHint) {
    if (_deviceLocales.isEmpty) return appLanguageHint;

    String normalize(String code) => code.toLowerCase().replaceAll('_', '-');
    String primarySubtag(String code) => normalize(code).split('-').first;

    final normalizedTarget = normalize(appLanguageHint);
    for (final locale in _deviceLocales) {
      if (normalize(locale.localeId) == normalizedTarget) return locale.localeId;
    }

    final targetPrimary = primarySubtag(appLanguageHint);
    for (final locale in _deviceLocales) {
      if (primarySubtag(locale.localeId) == targetPrimary) return locale.localeId;
    }

    return appLanguageHint;
  }

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    required void Function(String message) onError,
  }) async {
    _currentOnResult = onResult;
    _currentOnSoundLevel = onSoundLevel;
    _currentOnError = onError;
    _stopRequested = false;
    _committedTranscript = '';

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        onError('Speech recognition is not available on this device.');
        return;
      }
    }

    _activeLocaleId = _resolveLocaleId(localeCode);
    await _listenOnce();
  }

  Future<void> _listenOnce() async {
    // Defensively tear down any lingering session before starting a new
    // one — a recognizer left in a non-idle state (e.g. after a previous
    // error, or one of our own silence-triggered restarts) is a known cause
    // of a stray `error_client` on the next start.
    await _speech.cancel();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final segment = result.recognizedWords;
        final combined = _committedTranscript.isEmpty
            ? segment
            : (segment.isEmpty ? _committedTranscript : '$_committedTranscript $segment');

        if (!result.finalResult) {
          _currentOnResult?.call(combined, false);
          return;
        }

        _committedTranscript = combined;
        if (_stopRequested) {
          _currentOnResult?.call(combined, true);
        } else {
          // The OS ended this chunk on its own (silence) — keep the
          // session alive from the caller's point of view.
          _currentOnResult?.call(combined, false);
          _restartUnlessStopped();
        }
      },
      onSoundLevelChange: _currentOnSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        localeId: _activeLocaleId,
        // Maps to Android's EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS.
        // Some OEM recognizers (notably ColorOS/Realme) never fire
        // onPartialResults at all — the only way text appears "live" there
        // is via the OS-silence-triggered chunk restart above, so keeping
        // this short (instead of the device's multi-second default) is what
        // makes speech show up promptly instead of only after a long pause
        // or full stop.
        pauseFor: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _stopRequested = true;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _stopRequested = true;
    await _speech.cancel();
  }

  @override
  bool get isListening => _speech.isListening;
}
