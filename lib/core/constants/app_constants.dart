/// App-wide constant values that aren't tied to any single feature.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Voice Docs AI';

  /// Debounce applied to typed text before auto-translating, so we don't
  /// fire a network request on every keystroke.
  static const Duration translateDebounce = Duration(milliseconds: 500);

  static const int maxHistoryItems = 200;

  static const String defaultSourceLanguageCode = 'en';
  static const String defaultTargetLanguageCode = 'es';
}

/// SharedPreferences keys, centralized so a typo can't silently create a
/// second, disconnected storage slot.
class PrefsKeys {
  const PrefsKeys._();

  static const String history = 'voxi.history.v1';
  static const String settings = 'voxi.settings.v1';
  static const String folders = 'voxi.folders.v1';
}
