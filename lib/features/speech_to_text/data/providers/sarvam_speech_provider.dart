import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'speech_provider.dart';

/// [SpeechProvider] backed by Sarvam AI's speech-to-text REST endpoint —
/// strong on Indian languages, where the on-device recognizer tends to be
/// weakest.
///
/// Two consequences of it being a plain upload-and-wait REST call:
///
/// * No live partial captions while you speak. [onResult] only fires once
///   the recording has been uploaded and transcribed.
/// * Sarvam's synchronous endpoint accepts at most 30 seconds of audio per
///   request, which a spoken journal entry blows past easily. So the
///   recording is captured as raw PCM and split into sub-30s pieces that are
///   sent in order and stitched back together — see [_transcribe]. Each
///   piece's text is pushed out as a non-final result, so a long recording
///   fills in progressively instead of sitting on a blank screen.
class SarvamSpeechProvider implements SpeechProvider {
  SarvamSpeechProvider({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint = 'https://api.sarvam.ai/speech-to-text';
  static const _model = 'saaras:v3';
  static const _sampleRate = 16000;
  static const _bytesPerSample = 2;

  /// Sarvam's cap is 30s; leave headroom so a slightly-long final chunk
  /// can't trip it.
  static const _maxChunkSeconds = 28;
  static const _maxChunkBytes = _maxChunkSeconds * _sampleRate * _bytesPerSample;

  /// When splitting, look this far back from the cut point for a quiet spot,
  /// so chunk boundaries tend to land between words rather than mid-syllable.
  static const _silenceSearchSeconds = 3;

  /// Sarvam only speaks Indian languages, keyed by the language part of the
  /// app's BCP-47 locale hint. Anything else is sent as `unknown`, which asks
  /// Sarvam to auto-detect rather than failing the request outright.
  static const _sarvamLanguageByPrefix = <String, String>{
    'en': 'en-IN',
    'hi': 'hi-IN',
    'bn': 'bn-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'mr': 'mr-IN',
    'or': 'od-IN',
    'pa': 'pa-IN',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'gu': 'gu-IN',
    'as': 'as-IN',
    'ur': 'ur-IN',
    'ne': 'ne-IN',
    'kok': 'kok-IN',
    'ks': 'ks-IN',
    'sd': 'sd-IN',
    'sa': 'sa-IN',
    'sat': 'sat-IN',
    'mni': 'mni-IN',
    'brx': 'brx-IN',
    'mai': 'mai-IN',
    'doi': 'doi-IN',
  };

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
      onError('Add a Sarvam AI API key in Settings to use this speech engine.');
      return;
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      onError('Microphone permission is required to use voice input.');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sarvam_stt_${DateTime.now().microsecondsSinceEpoch}.pcm';
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
        final text = await _recognize(toWav(Uint8List.sublistView(pcm, start, end)));
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

  Future<String> _recognize(Uint8List wav) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        wav,
        filename: 'audio.wav',
        contentType: DioMediaType('audio', 'wav'),
      ),
      'model': _model,
      'language_code': sarvamLanguageCode(_currentLocaleCode),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      data: form,
      options: Options(headers: {'api-subscription-key': apiKey}),
    );
    return (response.data?['transcript'] as String? ?? '').trim();
  }

  @visibleForTesting
  static String sarvamLanguageCode(String localeCode) {
    final prefix = localeCode.split(RegExp('[-_]')).first.toLowerCase();
    return _sarvamLanguageByPrefix[prefix] ?? 'unknown';
  }

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

  /// Wraps raw mono 16-bit PCM in a 44-byte WAV header. Sarvam accepts bare
  /// PCM too, but only with a matching `input_audio_codec`; a self-describing
  /// WAV avoids that whole class of mismatch.
  @visibleForTesting
  static Uint8List toWav(Uint8List pcm) {
    const headerSize = 44;
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = _sampleRate * channels * bitsPerSample ~/ 8;

    final out = Uint8List(headerSize + pcm.length);
    final view = ByteData.sublistView(out);

    void ascii(int offset, String tag) {
      for (var i = 0; i < tag.length; i++) {
        out[offset + i] = tag.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    view.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    view.setUint16(20, 1, Endian.little); // format = PCM
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, _sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little); // block align
    view.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    view.setUint32(40, pcm.length, Endian.little);
    out.setRange(headerSize, headerSize + pcm.length, pcm);
    return out;
  }

  String _readableError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Sarvam rejected the API key. Check it in Settings.';
    }
    if (status == 429) {
      return 'Sarvam rate limit reached. Wait a moment and try again.';
    }

    // Sarvam surfaces messages as either {"error": {"message": ...}} or
    // FastAPI's {"detail": ...}, and `detail` is sometimes a list of
    // validation objects rather than a string.
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) return error['message'] as String;
      if (error is String) return error;

      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach Sarvam. Check your internet connection.';
    }
    return 'Sarvam speech recognition failed: ${e.message}';
  }
}
