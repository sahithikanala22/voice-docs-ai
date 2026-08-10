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

  /// Base URL of the Vercel-hosted OTP backend (see `server/`), exposing
  /// `/api/sendOtp` and `/api/verifyOtp`. Replace with the real deployment
  /// URL from the Vercel dashboard once it's live — no trailing slash.
  static const String otpApiBaseUrl = 'https://REPLACE_WITH_YOUR_VERCEL_DEPLOYMENT.vercel.app';
}

/// SharedPreferences keys, centralized so a typo can't silently create a
/// second, disconnected storage slot.
class PrefsKeys {
  const PrefsKeys._();

  static const String history = 'voxi.history.v1';
  static const String settings = 'voxi.settings.v1';
}
