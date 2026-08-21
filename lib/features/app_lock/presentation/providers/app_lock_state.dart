import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/app_lock_account.dart';

part 'app_lock_state.freezed.dart';

/// `account == null` means no local account has been created yet (first
/// launch → show signup). `isUnlocked` resets to false on every fresh app
/// process start (in-memory only, never persisted) — that's what makes the
/// PIN screen show up "while entering the app" rather than just once ever.
@freezed
class AppLockState with _$AppLockState {
  const factory AppLockState({
    AppLockAccount? account,
    @Default(false) bool isUnlocked,
    String? errorMessage,
  }) = _AppLockState;
}
