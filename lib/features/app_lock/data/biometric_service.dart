import 'package:local_auth/local_auth.dart';

/// Thin wrapper over `local_auth` so the rest of the app never touches the
/// plugin directly. Every failure mode (no hardware, nothing enrolled, user
/// cancelled, too many attempts) collapses to `false` — the PIN is always the
/// fallback, so callers only need a yes/no.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True only when the device has biometric hardware *and* at least one
  /// fingerprint/face is enrolled.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// `biometricOnly` so the phone's own PIN/pattern can't stand in — this
  /// app has its own PIN for that.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on Exception {
      return false;
    }
  }
}
