import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth` — fingerprint/face unlock as an
/// alternative to typing the PIN, never a replacement for it (there's no
/// server here to fall back on, so the PIN stays the ground truth; this
/// just offers a faster way in when the device supports it).
class BiometricAuthService {
  final _auth = LocalAuthentication();

  /// Whether this device can actually do biometric auth right now — has the
  /// hardware, the OS supports it, and something is enrolled. Used to decide
  /// whether to even show the Settings toggle in the first place.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS's own fingerprint/face dialog. `biometricOnly: true` so
  /// this never silently falls back to the phone's own system PIN/pattern —
  /// the point of the toggle is specifically fingerprint/face, and this
  /// app's PIN entry is right there as the other option.
  /// Recovery requires the OS device credential or biometrics, so resetting
  /// an app PIN cannot be used to bypass the lock and read existing entries.
  Future<bool> authenticateRecovery() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verify device ownership to reset your app PIN',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Voice Docs AI',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
