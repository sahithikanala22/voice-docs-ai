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
class OnDeviceSpeechProvider implements SpeechProvider {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  List<stt.LocaleName> _deviceLocales = [];

  void Function(String transcript, bool isFinal)? _currentOnResult;
  void Function(double level)? _currentOnSoundLevel;
  void Function(String message)? _currentOnError;
  bool _stopRequested = false;
  String _committedTranscript = '';
  String _activeLocaleId = '';

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: _handleNativeError,
      onStatus: (_) {},
    );
    if (_initialized) {
      _deviceLocales = await _speech.locales();
    }
    return _initialized;
  }

  void _handleNativeError(SpeechRecognitionError error) {
    final isSilencePause = error.errorMsg == 'error_no_match' || error.errorMsg == 'error_speech_timeout';
    if (isSilencePause && !_stopRequested) {
      _listenOnce();
      return;
    }
    _currentOnError?.call(_friendlyError(error.errorMsg));
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
          _listenOnce();
        }
      },
      onSoundLevelChange: _currentOnSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        localeId: _activeLocaleId,
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
