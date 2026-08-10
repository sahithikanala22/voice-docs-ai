import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

/// Transient UI state for the login/signup forms — the real "is a user
/// signed in" truth lives in [authStateChangesProvider], streamed straight
/// from Firebase; this only tracks the in-flight submit button and any
/// error to show.
@freezed
class AuthFormState with _$AuthFormState {
  const factory AuthFormState({
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _AuthFormState;
}
