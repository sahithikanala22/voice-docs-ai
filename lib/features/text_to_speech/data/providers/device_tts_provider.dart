import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/tts_voice_option.dart';
import 'tts_provider.dart';

/// Default [TtsProvider]: wraps `flutter_tts`, which talks to the native OS
/// text-to-speech engine on every platform. Free, no API key, fully offline.
class DeviceTtsProvider implements TtsProvider {
  DeviceTtsProvider() {
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();
  List<String>? _deviceLanguages;
  List<TtsVoiceOption>? _deviceVoices;

  Future<List<String>> _loadDeviceLanguages() async {
    if (_deviceLanguages != null) return _deviceLanguages!;
    try {
      final result = await _tts.getLanguages;
      _deviceLanguages = (result as List).map((e) => e.toString()).toList();
    } catch (_) {
      _deviceLanguages = const [];
    }
    return _deviceLanguages!;
  }

  Future<List<TtsVoiceOption>> _loadDeviceVoices() async {
    if (_deviceVoices != null) return _deviceVoices!;
    try {
      final result = await _tts.getVoices as List;
      _deviceVoices = result
          .whereType<Map>()
          .map((v) => TtsVoiceOption(
                name: v['name']?.toString() ?? '',
                locale: v['locale']?.toString() ?? '',
              ))
          .where((v) => v.name.isNotEmpty && v.locale.isNotEmpty)
          .toList();
    } catch (_) {
      _deviceVoices = const [];
    }
    return _deviceVoices!;
  }

  /// Mirrors [OnDeviceSpeechProvider]'s locale resolution. [languageHint] is
  /// already a full, region-qualified locale (e.g. `en-US` — see
  /// `Language.localeHint`), since the OS text-to-speech engine rejects bare
  /// codes. This only *upgrades* to an exact device-reported entry when one
  /// matches; it never falls back to an unrelated device language just
  /// because the hint wasn't found; that would silently speak in the wrong
  /// language.
  String _resolveLanguage(String languageHint, List<String> deviceLanguages) {
    if (deviceLanguages.isEmpty) return languageHint;

    String normalize(String code) => code.toLowerCase().replaceAll('_', '-');
    String primarySubtag(String code) => normalize(code).split('-').first;

    final normalizedTarget = normalize(languageHint);
    for (final language in deviceLanguages) {
      if (normalize(language) == normalizedTarget) return language;
    }

    final targetPrimary = primarySubtag(languageHint);
    for (final language in deviceLanguages) {
      if (primarySubtag(language) == targetPrimary) return language;
    }

    return languageHint;
  }

  @override
  Future<List<TtsVoiceOption>> getVoices(String languageCode) async {
    final voices = await _loadDeviceVoices();
    String normalize(String code) => code.toLowerCase().replaceAll('_', '-');
    String primarySubtag(String code) => normalize(code).split('-').first;

    final normalizedTarget = normalize(languageCode);
    final exact = voices.where((v) => normalize(v.locale) == normalizedTarget).toList();
    if (exact.isNotEmpty) return exact;

    final targetPrimary = primarySubtag(languageCode);
    return voices.where((v) => primarySubtag(v.locale) == targetPrimary).toList();
  }

  @override
  Future<void> speak(String text, String languageCode, {String? voiceName}) async {
    final deviceLanguages = await _loadDeviceLanguages();
    final resolvedLanguage = _resolveLanguage(languageCode, deviceLanguages);
    await _tts.setLanguage(resolvedLanguage);

    if (voiceName != null) {
      final voices = await getVoices(languageCode);
      final match = voices.where((v) => v.name == voiceName).toList();
      if (match.isNotEmpty) {
        await _tts.setVoice({'name': match.first.name, 'locale': match.first.locale});
      }
    }

    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  void onStart(void Function() callback) => _tts.setStartHandler(callback);

  @override
  void onComplete(void Function() callback) => _tts.setCompletionHandler(callback);

  @override
  void onError(void Function(String message) callback) {
    _tts.setErrorHandler((dynamic message) => callback(message.toString()));
  }
}
