import 'dart:async';
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
/// Bluetooth headset mic support: the plugin tries this automatically, but
/// only if `BLUETOOTH_CONNECT` (Android 12+) is already granted by the time
/// its native `initialize()` runs — otherwise it silently falls back to the
/// phone's built-in mic. Since [SpeechController.startListening] already
/// pre-grants `RECORD_AUDIO` before calling this class's [initialize], the
/// plugin's own internal Bluetooth-permission request never fires (it's
/// gated behind "if audio permission isn't already granted"), so that
/// controller requests `bluetoothConnect` itself first — see its comment.
class OnDeviceSpeechProvider implements SpeechProvider {
  OnDeviceSpeechProvider({
    stt.SpeechToText? speech,
    this.restartDelay = const Duration(milliseconds: 250),
    this.maxEmptyRestarts = 5,
  }) : _speech = speech ?? stt.SpeechToText();
  final stt.SpeechToText _speech;
  final Duration restartDelay;
  final int maxEmptyRestarts;
  int _listenSerial = 0, _emptyRestarts = 0;
  String _partial = '';
  bool _hasListened = false;
  Future<void>? _listenOperation;
  bool _initialized = false;
  int _generation = 0;
  bool _restarting = false;
  Timer? _restartTimer;
  List<stt.LocaleName> _deviceLocales = [];

  void Function(String transcript, bool isFinal)? _currentOnResult;
  void Function(double level)? _currentOnSoundLevel;
  void Function(String message)? _currentOnError;
  bool _stopRequested = false;
  String _committedTranscript = '';
  String _activeLocaleId = '';

  @override
  Future<bool> initialize() async {
    // SpeechToText is a singleton and initialize() keeps the first listeners.
    // Rebind them when settings recreate this provider or switch engines back.
    _speech.errorListener = _handleNativeError;
    _speech.statusListener = _handleNativeStatus;
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: _handleNativeError,
      onStatus: _handleNativeStatus,
    );
    if (_initialized) {
      _deviceLocales = await _speech.locales();
    }
    return _initialized;
  }

  void _handleNativeStatus(String status) {
    if (!_stopRequested &&
        !_restarting &&
        (status == 'done' || status == 'notListening')) {
      _scheduleRestart();
    }
  }

  void _handleNativeError(SpeechRecognitionError error) {
    if (_stopRequested) return;
    final isSilencePause =
        error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout';
    if (isSilencePause && !_stopRequested) {
      _scheduleRestart();
      return;
    }
    _stopRequested = true;
    _restartTimer?.cancel();
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
        return 'The language model is unavailable. Download the language in your device speech settings, or use Record meeting to keep audio without a model.';
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
      if (normalize(locale.localeId) == normalizedTarget) {
        return locale.localeId;
      }
    }

    final targetPrimary = primarySubtag(appLanguageHint);
    for (final locale in _deviceLocales) {
      if (primarySubtag(locale.localeId) == targetPrimary) {
        return locale.localeId;
      }
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
    _generation++;
    _currentOnResult = onResult;
    _currentOnSoundLevel = onSoundLevel;
    _currentOnError = onError;
    _stopRequested = false;
    _committedTranscript = '';
    _partial = '';
    _emptyRestarts = 0;
    _hasListened = false;
    _restartTimer?.cancel();

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

  void _scheduleRestart() {
    if (_stopRequested || (_restartTimer?.isActive ?? false)) return;
    _restartTimer = Timer(restartDelay * (1 << _emptyRestarts.clamp(0, 4)), () {
      if (!_stopRequested) unawaited(_listenOnce());
    });
  }

  Future<void> _listenOnce() => _listenOperation ??= _performListen()
      .whenComplete(() => _listenOperation = null);

  Future<void> _performListen() async {
    if (_stopRequested || _restarting) return;
    final generation = _generation;
    if (_hasListened && _partial.isEmpty) _emptyRestarts++;
    if (_partial.isNotEmpty) {
      _committedTranscript = [
        _committedTranscript,
        _partial,
      ].where((s) => s.isNotEmpty).join(' ');
      _partial = '';
      _emptyRestarts = 0;
    }
    if (_emptyRestarts > maxEmptyRestarts) {
      _stopRequested = true;
      _currentOnError?.call(
        'Speech recognition repeatedly ended without speech. Audio is not archived in device dictation; use Record meeting for important recordings.',
      );
      return;
    }
    final serial = ++_listenSerial;
    var segmentCommitted = false;
    _hasListened = true;
    _restarting = true;
    try {
      // Defensively tear down any lingering session before starting a new
      // one — a recognizer left in a non-idle state (e.g. after a previous
      // error, or one of our own silence-triggered restarts) is a known cause
      // of a stray `error_client` on the next start.
      await _speech.cancel();
      if (_stopRequested || generation != _generation) return;
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (generation != _generation ||
              serial != _listenSerial ||
              segmentCommitted) {
            return;
          }
          final segment = result.recognizedWords;
          _partial = segment;
          if (segment.isNotEmpty) _emptyRestarts = 0;
          final combined = _committedTranscript.isEmpty
              ? segment
              : (segment.isEmpty
                    ? _committedTranscript
                    : '$_committedTranscript $segment');

          if (!result.finalResult) {
            _currentOnResult?.call(combined, false);
            return;
          }

          _committedTranscript = combined;
          _partial = '';
          segmentCommitted = true;
          if (_stopRequested) {
            _currentOnResult?.call(combined, true);
          } else {
            // The OS ended this chunk on its own (silence) — keep the
            // session alive from the caller's point of view.
            _currentOnResult?.call(combined, false);
            _scheduleRestart();
          }
        },
        onSoundLevelChange: _currentOnSoundLevel,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          localeId: _activeLocaleId,
          // Let the OS detect silence. The plugin's pauseFor timer counts
          // time without text results, including recognizer startup and
          // ongoing speech on devices that don't deliver partial results.
          // A short timeout therefore cuts off actual speech. Native session
          // completion still schedules the next segment above.
        ),
      );
    } catch (_) {
      if (!_stopRequested) {
        _currentOnError?.call('Speech recognition was interrupted.');
      }
    } finally {
      _restarting = false;
    }
  }

  @override
  Future<void> stopListening() async {
    _stopRequested = true;
    _restartTimer?.cancel();
    await _listenOperation;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _stopRequested = true;
    _restartTimer?.cancel();
    _generation++;
    _currentOnResult = null;
    _currentOnError = null;
    _currentOnSoundLevel = null;
    await _listenOperation;
    await _speech.cancel();
  }

  @override
  bool get isListening => _speech.isListening;
}
