import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'speech_provider.dart';

/// The model this provider uses — also read by `WhisperSpeechSettings` so
/// its "is the model already downloaded" check can never drift from what
/// actually gets used for transcription. `base` is whisper_ggml's own
/// recommended default for live transcription: noticeably more accurate
/// than `tiny`, still fast enough not to visibly lag behind speech on a
/// modern phone.
const whisperSpeechModel = WhisperModel.base;

/// [SpeechProvider] backed by [whisper_ggml] — OpenAI's Whisper model
/// running fully on-device via whisper.cpp. Free forever (no API key, no
/// per-use billing), works offline once its model file is downloaded once,
/// and is generally more accurate than the phone's own OS recognizer,
/// especially with accents — at the cost of a one-time ~140MB model
/// download and more CPU/battery per recording than the lightweight OS
/// engine.
///
/// Unlike the Google Cloud provider, this genuinely streams: the model
/// stays loaded for the session and [startWhisperLiveSession]
/// emits progressively-refined partial transcripts while you talk, so live
/// captions work the same way they do for the on-device engine — no
/// restart-on-silence stitching needed, there's no OS-imposed silence
/// timeout to work around here.
class WhisperSpeechProvider implements SpeechProvider {
  WhisperSpeechProvider({this.model = whisperSpeechModel, WhisperController? controller})
    : _controller = controller ?? WhisperController();

  final WhisperModel model;

  final WhisperController _controller;
  final AudioRecorder _recorder = AudioRecorder();

  WhisperLiveSession? _session;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  void Function(String transcript, bool isFinal)? _currentOnResult;
  bool _isListening = false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    required void Function(String message) onError,
  }) async {
    // Only one native stream session can run at a time (see
    // WhisperLiveSession's doc comment) — a lingering session from an
    // unclean teardown (e.g. the caller skipped stopListening/cancel, or a
    // previous call raced this one) would otherwise make the native side
    // reject this session's audio with "stream_feed: stream not started".
    // Defensively tear it down first, same pattern as the on-device
    // provider's _listenOnce.
    if (_isListening) await stopListening();

    _currentOnResult = onResult;

    final granted = await _recorder.hasPermission();
    if (!granted) {
      onError('Microphone permission is required to use voice input.');
      return;
    }

    try {
      // transcribeLive throws if the model file isn't already on disk —
      // download it first rather than let that surface as an opaque
      // "could not start" error. A no-op once it's been fetched once (see
      // WhisperSpeechSettings, which lets this happen ahead of time instead
      // of during someone's first recording).
      await _controller.downloadModel(model);
    } catch (e) {
      onError('Could not download the offline speech model: $e');
      return;
    }

    try {
      final pcmStream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );

      if (onSoundLevel != null) {
        _amplitudeSubscription = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 150))
            .listen((amplitude) {
              // amplitude.current is dBFS, roughly -50 (near-silence)..0
              // (loudest) in practice — remap to the 0..10 scale the rest of
              // the app's mic-pulse animation expects.
              onSoundLevel(((amplitude.current + 50) / 5).clamp(0.0, 10.0));
            });
      }

      // Calls the lower-level session starter directly rather than going
      // through WhisperController.transcribeLive, which hardcodes 4 threads
      // with no way to override it — most phones sold in the last several
      // years have 6-8 cores, so that default leaves real, free speed on
      // the table. Same model, same weights, same accuracy; just more of
      // the phone's own CPU actually put to work.
      _session = await startWhisperLiveSession(
        modelPath: await _controller.getPath(model),
        lang: whisperLanguageCode(localeCode),
        threads: Platform.numberOfProcessors.clamp(1, 8),
        // Without this, every single recording — not just the first —
        // reloads the ~140MB model from disk into native memory before
        // transcribing a word, which is most of what "Whisper feels slow"
        // reports turn out to be. Parking it after stop() means only the
        // very first recording in a session pays that cost; the trade is
        // the model staying resident in memory meanwhile, which is the
        // right call for an app whose whole premise is on-device
        // transcription someone may use repeatedly.
        keepModelLoaded: true,
      );
      _isListening = true;
      // startWhisperLiveSession, unlike WhisperController.transcribeLive,
      // doesn't take the audio stream itself — it only returns the session,
      // and leaves wiring audio into it to the caller. This mirrors exactly
      // what transcribeLive does internally.
      pcmStream.listen(_session!.feed, onDone: _session!.stop, onError: (Object _) => _session!.stop());
      _session!.partials.listen(
        // "Progressively refined transcripts... the full text so far, not a
        // delta" — matches this app's onResult contract exactly, no
        // stitching needed.
        (text) => _currentOnResult?.call(stripNonSpeechTokens(text), false),
        onError: (Object e) => onError(_friendlyError(e)),
      );
    } catch (e) {
      _isListening = false;
      await _amplitudeSubscription?.cancel();
      onError('Could not start offline speech recognition: $e');
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _amplitudeSubscription?.cancel();
    await _recorder.stop();
    // Closing the stream above already makes transcribeLive's internal
    // listener call session.stop() (see its onDone handler); calling it
    // again here is safe — WhisperLiveSession.stop() is idempotent — and is
    // how this method gets the final transcript back.
    final finalText = await _session?.stop() ?? '';
    _session = null;
    _currentOnResult?.call(stripNonSpeechTokens(finalText), true);
  }

  @override
  Future<void> cancel() async {
    _isListening = false;
    await _amplitudeSubscription?.cancel();
    await _recorder.cancel();
    await _session?.stop();
    _session = null;
  }

  @override
  bool get isListening => _isListening;

  /// Whisper's language codes are bare ISO-639-1 ('en', 'hi', 'te', ...);
  /// the app's locale hints are full BCP-47 ('en-US') and a couple
  /// (`zh-CN`/`zh-TW`) are the app's own `Language.code`, not a hint — the
  /// primary subtag is what both forms have in common.
  @visibleForTesting
  static String whisperLanguageCode(String localeCode) =>
      localeCode.split(RegExp('[-_]')).first.toLowerCase();

  /// The base/tiny Whisper models frequently "transcribe" silence or
  /// unclear audio as a literal bracketed/parenthesized descriptor —
  /// `[BLANK_AUDIO]`, `(silence)`, `[no speech]`, `[inaudible]`, `[music]`,
  /// `[noise]` — instead of just emitting no text. Left in, that reads as
  /// broken output ("why does it say BLANK_AUDIO") rather than "nothing
  /// recognizable yet", so every occurrence is stripped wherever it shows
  /// up in the running transcript, not just when it's the whole string —
  /// a long dictation can have a quiet stretch tagged mid-sentence.
  @visibleForTesting
  static final nonSpeechTokenPattern = RegExp(
    r'[\[(]\s*(blank[_ ]?audio|no\s*speech|silence|inaudible|music|noise)\s*[\])]',
    caseSensitive: false,
  );

  @visibleForTesting
  static String stripNonSpeechTokens(String text) =>
      text.replaceAll(nonSpeechTokenPattern, '').replaceAll(RegExp(r' {2,}'), ' ').trim();

  /// `transcribeLive`'s stream errors are raw native/FFI exception text
  /// (e.g. `Exception: stream_feed: stream not started`) — not meant for a
  /// user to read. The specific "stream not started" case is the native
  /// side rejecting audio because the prior session's teardown hadn't
  /// finished when this one's native stream tried to start (now guarded
  /// against in [startListening], but the native layer can still surface it
  /// under load); tell the user to just try again rather than showing them
  /// FFI internals.
  static String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('stream_feed') || message.contains('stream not started')) {
      return 'Speech recognition was interrupted — tap the mic to try again.';
    }
    return 'Speech recognition error: $message';
  }
}
