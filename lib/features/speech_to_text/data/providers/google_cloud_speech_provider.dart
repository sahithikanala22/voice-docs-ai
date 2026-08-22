import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'speech_provider.dart';

/// [SpeechProvider] backed by Google Cloud Speech-to-Text's *batch* REST
/// endpoint (`speech:recognize`) — chosen over the streaming API because
/// streaming needs OAuth/service-account credentials that can't safely ship
/// in a client app, while a plain API key (restricted to this app's
/// signing certificate in Google Cloud Console) is safe to embed and works
/// fine with the batch endpoint.
///
/// Practical effect: no live partial captions — [onResult] fires once,
/// with the full transcript, right after [stopListening] uploads the
/// recording and gets a response back. Requires an internet connection and
/// a user-supplied API key (Settings); bills per use past Google's free
/// tier.
class GoogleCloudSpeechProvider implements SpeechProvider {
  GoogleCloudSpeechProvider({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();

  static const _sampleRate = 16000;
  static const _endpoint = 'https://speech.googleapis.com/v1/speech:recognize';

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
      final path = '${dir.path}/gcloud_stt_${DateTime.now().microsecondsSinceEpoch}.pcm';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sampleRate, numChannels: 1),
        path: path,
      );
      _isListening = true;

      if (onSoundLevel != null) {
        _amplitudeSubscription =
            _recorder.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((amplitude) {
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
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _currentOnResult?.call('', true);
        return;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {'key': apiKey},
        data: {
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': _sampleRate,
            'languageCode': _currentLocaleCode,
            'enableAutomaticPunctuation': true,
          },
          'audio': {'content': base64Encode(bytes)},
        },
      );

      final results = response.data?['results'] as List<dynamic>?;
      final transcript = (results ?? const [])
          .map((r) => ((r as Map<String, dynamic>)['alternatives'] as List<dynamic>).first
              as Map<String, dynamic>)
          .map((alt) => alt['transcript'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .join(' ');

      _currentOnResult?.call(transcript, true);
    } on DioException catch (e) {
      String? apiMessage;
      final responseData = e.response?.data;
      if (responseData is Map) {
        final error = responseData['error'];
        if (error is Map) apiMessage = error['message'] as String?;
      }
      _currentOnError?.call(apiMessage ?? 'Google Cloud speech recognition failed: ${e.message}');
    } catch (e) {
      _currentOnError?.call('Could not transcribe the recording: $e');
    } finally {
      unawaited(file.exists().then((exists) async {
        if (exists) await file.delete();
      }));
    }
  }
}
