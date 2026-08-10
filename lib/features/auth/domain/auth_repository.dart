/// Minimal authenticated-user view the rest of the app needs — presentation
/// code depends on this, never on `firebase_auth` types directly, so the
/// backend could be swapped without touching UI code.
class AppUser {
  const AppUser({required this.uid, this.phoneNumber});

  final String uid;
  final String? phoneNumber;
}

abstract class AuthRepository {
  /// Emits the current user on every sign-in/sign-out, including once
  /// immediately with whatever session Firebase already had persisted.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Triggers the `sendOtp` Cloud Function, which generates a code and
  /// delivers it over WhatsApp via Twilio. [phoneNumber] must be in E.164
  /// format (e.g. `+14155551234`).
  Future<void> sendOtp(String phoneNumber);

  /// Triggers the `verifyOtp` Cloud Function; on a correct code it signs in
  /// with the custom token the backend mints, which is what actually flips
  /// [authStateChanges].
  Future<void> verifyOtp({required String phoneNumber, required String code});

  Future<void> signOut();
}
