import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'speech_provider.dart';

/// [SpeechProvider] backed by Google Cloud's `speech:recognize` REST
/// endpoint — needs a Google Cloud project with the Speech-to-Text API
/// enabled, billing turned on, and an API key.
///
/// Two consequences of it being a plain upload-and-wait REST call (same
/// shape as [SpeechProvider]'s other cloud option used to be):
///
/// * No live partial captions while you speak. [onResult] only fires once
///   the recording has been uploaded and transcribed.
/// * The synchronous `recognize` endpoint accepts at most ~60 seconds of
///   audio per request, which a spoken journal entry can blow past. So the
///   recording is captured as raw PCM and split into sub-cap pieces that are
///   sent in order and stitched back together — see [_transcribe]. Each
///   piece's text is pushed out as a non-final result, so a long recording
///   fills in progressively instead of sitting on a blank screen.
class GoogleSpeechProvider implements SpeechProvider {
  GoogleSpeechProvider({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint = 'https://speech.googleapis.com/v1/speech:recognize';

  static const _sampleRate = 16000;
  static const _bytesPerSample = 2;

  /// Google's sync endpoint caps at ~60s; leave real headroom so a
  /// slightly-long final chunk can't trip it.
  static const _maxChunkSeconds = 55;
  static const _maxChunkBytes = _maxChunkSeconds * _sampleRate * _bytesPerSample;

  /// When splitting, look this far back from the cut point for a quiet spot,
  /// so chunk boundaries tend to land between words rather than mid-syllable.
  static const _silenceSearchSeconds = 3;

  final String apiKey;
  final Dio _dio;
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  void Function(String transcript, bool isFinal)? _currentOnResult;
  void Function(String message)? _currentOnError;
  String _currentLocaleCode = 'en-US';
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
    _currentOnError = onError;
    _currentLocaleCode = localeCode;

    if (apiKey.trim().isEmpty) {
      onError('Add a Google Cloud API key in Settings to use this speech engine.');
      return;
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      onError('Microphone permission is required to use voice input.');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/google_stt_${DateTime.now().microsecondsSinceEpoch}.pcm';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      _isListening = true;

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
    } catch (e) {
      _isListening = false;
      onError('Could not start recording: $e');
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _amplitudeSubscription?.cancel();

    final path = await _recorder.stop();
    if (path == null) {
      _currentOnResult?.call('', true);
      return;
    }
    await _transcribe(path);
  }

  @override
  Future<void> cancel() async {
    _isListening = false;
    await _amplitudeSubscription?.cancel();
    await _recorder.cancel();
  }

  @override
  bool get isListening => _isListening;

  Future<void> _transcribe(String path) async {
    final file = File(path);
    try {
      final pcm = await file.readAsBytes();
      if (pcm.isEmpty) {
        _currentOnResult?.call('', true);
        return;
      }

      final ranges = chunkRanges(pcm);
      final pieces = <String>[];

      for (var i = 0; i < ranges.length; i++) {
        final (start, end) = ranges[i];
        final text = await _recognize(Uint8List.sublistView(pcm, start, end));
        if (text.isNotEmpty) pieces.add(text);

        final isLast = i == ranges.length - 1;
        // Push what we have so far after every chunk so a long recording
        // visibly fills in; only the last call is marked final.
        _currentOnResult?.call(pieces.join(' '), isLast);
      }

      if (ranges.isEmpty) _currentOnResult?.call('', true);
    } on DioException catch (e) {
      _currentOnError?.call(_readableError(e));
    } catch (e) {
      _currentOnError?.call('Could not transcribe the recording: $e');
    } finally {
      unawaited(
        file.exists().then((exists) async {
          if (exists) await file.delete();
        }),
      );
    }
  }

  Future<String> _recognize(Uint8List pcm) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      queryParameters: {'key': apiKey},
      data: {
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': _sampleRate,
          'languageCode': googleLanguageCode(_currentLocaleCode),
          'enableAutomaticPunctuation': true,
        },
        'audio': {'content': base64Encode(pcm)},
      },
    );

    final results = response.data?['results'] as List<dynamic>? ?? const [];
    final pieces = <String>[];
    for (final result in results) {
      final alternatives = (result as Map<String, dynamic>)['alternatives'] as List<dynamic>?;
      final transcript = alternatives?.isNotEmpty == true
          ? (alternatives!.first as Map<String, dynamic>)['transcript'] as String?
          : null;
      if (transcript != null && transcript.isNotEmpty) pieces.add(transcript);
    }
    return pieces.join(' ').trim();
  }

  /// Google's API takes standard BCP-47 language codes directly — exactly
  /// what the app's `Language.localeHint` already is, so this is a
  /// pass-through rather than a lookup table.
  @visibleForTesting
  static String googleLanguageCode(String localeCode) => localeCode.trim();

  /// Byte ranges to upload, each at most [_maxChunkBytes] and aligned to
  /// whole 16-bit samples. Cuts are nudged back to the quietest moment in the
  /// preceding [_silenceSearchSeconds] so they tend to fall in a pause.
  @visibleForTesting
  static List<(int, int)> chunkRanges(Uint8List pcm) {
    final ranges = <(int, int)>[];
    var start = 0;
    while (start < pcm.length) {
      if (pcm.length - start <= _maxChunkBytes) {
        ranges.add((start, pcm.length));
        break;
      }
      final hardEnd = start + _maxChunkBytes;
      final end = _quietestCut(pcm, start, hardEnd);
      ranges.add((start, end));
      start = end;
    }
    return ranges;
  }

  /// Scans 20ms windows in the last [_silenceSearchSeconds] before [hardEnd]
  /// and returns the start of the quietest one, falling back to [hardEnd]
  /// when that window would be degenerate.
  static int _quietestCut(Uint8List pcm, int start, int hardEnd) {
    const windowBytes = _sampleRate ~/ 50 * _bytesPerSample; // 20ms
    final searchStart = max(start, hardEnd - _silenceSearchSeconds * _sampleRate * _bytesPerSample);
    if (hardEnd - searchStart < windowBytes * 2) return hardEnd;

    // ByteData.sublistView keeps this correct even though `pcm` may itself be
    // a view into a larger buffer.
    final samples = ByteData.sublistView(pcm);
    var bestOffset = hardEnd;
    var bestEnergy = double.infinity;

    for (var offset = searchStart; offset + windowBytes <= hardEnd; offset += windowBytes) {
      var energy = 0.0;
      for (var i = offset; i + _bytesPerSample <= offset + windowBytes; i += _bytesPerSample) {
        energy += samples.getInt16(i, Endian.little).abs();
      }
      if (energy < bestEnergy) {
        bestEnergy = energy;
        bestOffset = offset;
      }
    }
    // Keep the cut on a sample boundary.
    return bestOffset - (bestOffset % _bytesPerSample);
  }

  String _readableError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? message;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) message = error['message'] as String;
    }

    if (status == 400 || status == 403) {
      return message != null
          ? 'Google Cloud rejected the request: $message'
          : 'Google rejected the API key. Check it\'s valid and the Speech-to-Text API is enabled in Settings.';
    }
    if (status == 429) {
      return 'Google Cloud rate/quota limit reached. Wait a moment and try again.';
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach Google Cloud. Check your internet connection.';
    }
    return message ?? 'Google speech recognition failed: ${e.message}';
  }
}
