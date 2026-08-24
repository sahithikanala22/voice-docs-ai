import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  GoogleCloudSpeechProvider({required this.apiKey, Dio? dio})
    : _dio = dio ?? Dio();

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
      onError(
        'Add a Google Cloud API key in Settings to use this speech engine.',
      );
      return;
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      onError('Microphone permission is required to use voice input.');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/gcloud_stt_${DateTime.now().microsecondsSinceEpoch}.pcm';
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
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _currentOnResult?.call('', true);
        return;
      }

      Map<String, dynamic> data;
      try {
        // "latest_long" is Google's conversational model — tuned for
        // natural speech with pauses instead of the short, clipped
        // commands the default model expects — and diarization tags each
        // word with a speaker so a multi-person recording doesn't come
        // back as one run-on transcript.
        data = await _recognize(bytes, enhanced: true);
      } on DioException catch (e) {
        // Not every language supports the long model or diarization; fall
        // back to the plain config rather than losing the recording.
        if (e.response?.statusCode == 400) {
          data = await _recognize(bytes, enhanced: false);
        } else {
          rethrow;
        }
      }

      _currentOnResult?.call(_extractTranscript(data), true);
    } on DioException catch (e) {
      String? apiMessage;
      final responseData = e.response?.data;
      if (responseData is Map) {
        final error = responseData['error'];
        if (error is Map) apiMessage = error['message'] as String?;
      }
      _currentOnError?.call(
        apiMessage ?? 'Google Cloud speech recognition failed: ${e.message}',
      );
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

  Future<Map<String, dynamic>> _recognize(
    Uint8List bytes, {
    required bool enhanced,
  }) async {
    final config = <String, dynamic>{
      'encoding': 'LINEAR16',
      'sampleRateHertz': _sampleRate,
      'languageCode': _currentLocaleCode,
      'enableAutomaticPunctuation': true,
    };
    if (enhanced) {
      config['model'] = 'latest_long';
      config['diarizationConfig'] = {
        'enableSpeakerDiarization': true,
        'minSpeakerCount': 1,
        'maxSpeakerCount': 6,
      };
    }

    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      queryParameters: {'key': apiKey},
      data: {
        'config': config,
        'audio': {'content': base64Encode(bytes)},
      },
    );
    return response.data ?? const {};
  }

  /// Plain concatenation of each segment's transcript in the common case.
  /// When diarization found more than one speaker, Google appends one
  /// extra result whose first alternative carries word-level speaker tags
  /// for the whole recording — used instead to produce a "Speaker N: ..."
  /// transcript, but only when there's actually more than one speaker, so
  /// a normal solo journal entry doesn't get a needless "Speaker 1:" label.
  String _extractTranscript(Map<String, dynamic> data) {
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return '';

    final plainTranscript = results
        .map((r) {
          final alternatives =
              (r as Map<String, dynamic>)['alternatives'] as List<dynamic>?;
          if (alternatives == null || alternatives.isEmpty) return '';
          return (alternatives.first as Map<String, dynamic>)['transcript']
                  as String? ??
              '';
        })
        .where((t) => t.isNotEmpty)
        .join(' ');

    final lastAlternatives =
        (results.last as Map<String, dynamic>)['alternatives']
            as List<dynamic>?;
    final words = lastAlternatives == null || lastAlternatives.isEmpty
        ? null
        : (lastAlternatives.first as Map<String, dynamic>)['words']
              as List<dynamic>?;
    if (words == null || words.isEmpty) return plainTranscript;

    final speakerTags = words
        .map((w) => (w as Map<String, dynamic>)['speakerTag'] as int?)
        .whereType<int>()
        .toSet();
    if (speakerTags.length <= 1) return plainTranscript;

    final buffer = StringBuffer();
    int? currentSpeaker;
    for (final w in words) {
      final word = w as Map<String, dynamic>;
      final speaker = word['speakerTag'] as int? ?? 1;
      final text = word['word'] as String? ?? '';
      if (text.isEmpty) continue;
      if (speaker != currentSpeaker) {
        if (currentSpeaker != null) buffer.write('\n');
        buffer.write('Speaker $speaker: $text');
        currentSpeaker = speaker;
      } else {
        buffer.write(' $text');
      }
    }
    return buffer.toString().trim();
  }
}
