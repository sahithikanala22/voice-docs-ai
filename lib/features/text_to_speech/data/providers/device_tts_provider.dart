import 'package:flutter_tts/flutter_tts.dart';

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
  Future<void> speak(String text, String languageCode) async {
    final deviceLanguages = await _loadDeviceLanguages();
    await _tts.setLanguage(_resolveLanguage(languageCode, deviceLanguages));
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
