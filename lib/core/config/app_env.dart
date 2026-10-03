import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Values read from the bundled `.env` file at startup.
///
/// `.env` is gitignored, so it won't exist on a fresh clone or on CI — every
/// getter here falls back to empty rather than throwing, and [load] swallows
/// a missing file. See `.env.example` for the keys.
///
/// Anything put here is bundled into the APK as a plain asset and can be
/// read by anyone who unzips it. That's an acceptable trade for a personal
/// build; a key that actually needs protecting belongs behind a backend.
abstract final class AppEnv {
  static Future<void> load() async {
    try {
      await dotenv.load();
    } catch (_) {
      // No .env bundled (e.g. this release build). dotenv.load() throwing
      // leaves it uninitialized, and every getter below — including
      // maybeGet, despite the name — throws NotInitializedError against an
      // uninitialized DotEnv rather than returning null. Explicitly
      // initialize it empty so [sarvamApiKey] actually falls back to ''
      // as documented, instead of crashing the first screen that reads it
      // (Settings' Sarvam panel).
      dotenv.loadFromString(envString: '', isOptional: true);
    }
  }

  /// Default Sarvam AI key. A key entered in Settings takes precedence over
  /// this one; see `speechProviderImplProvider`.
  static String get sarvamApiKey => dotenv.maybeGet('SARVAM_API_KEY')?.trim() ?? '';
}
