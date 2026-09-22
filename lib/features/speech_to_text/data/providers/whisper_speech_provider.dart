import 'dart:async';

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
/// Unlike the Sarvam provider, this genuinely streams: the model
/// stays loaded for the session and [WhisperController.transcribeLive]
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

      _session = await _controller.transcribeLive(
        model: model,
        pcm16Stream: pcmStream,
        lang: whisperLanguageCode(localeCode),
      );
      _isListening = true;
      _session!.partials.listen(
        // "Progressively refined transcripts... the full text so far, not a
        // delta" — matches this app's onResult contract exactly, no
        // stitching needed.
        (text) => _currentOnResult?.call(text, false),
        onError: (Object e) => onError('Speech recognition error: $e'),
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
    _currentOnResult?.call(finalText, true);
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
}
