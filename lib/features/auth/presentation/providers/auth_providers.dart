import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/errors/exceptions.dart';

import '../../data/firebase_auth_repository.dart';
import '../../domain/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());

/// Streams the real, server-verified signed-in state. `app_router.dart`'s
/// redirect logic and `app.dart`'s initial-loading gate both key off this.
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Drives the phone-entry / OTP-verification screen: submit-in-flight +
/// error surfacing. A correct code itself doesn't need to be tracked here —
/// once Firebase confirms the resulting sign-in, [authStateChangesProvider]
/// emits the new user and the router redirect moves off the login screen
/// automatically.
final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(AuthController.new);

class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<bool> sendOtp(String phoneNumber) {
    return _run(() => ref.read(authRepositoryProvider).sendOtp(phoneNumber));
  }

  Future<bool> verifyOtp({required String phoneNumber, required String code}) {
    return _run(
      () => ref.read(authRepositoryProvider).verifyOtp(phoneNumber: phoneNumber, code: code),
    );
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  void dismissError() => state = state.copyWith(errorMessage: null);

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await action();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isSubmitting: false, errorMessage: 'Something went wrong. Try again.');
      return false;
    }
  }
}
