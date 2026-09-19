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
      // No .env bundled — the app still runs, and Settings can supply the key.
    }
  }

  /// Default Sarvam AI key. A key entered in Settings takes precedence over
  /// this one; see `speechProviderImplProvider`.
  static String get sarvamApiKey => dotenv.maybeGet('SARVAM_API_KEY')?.trim() ?? '';
}
