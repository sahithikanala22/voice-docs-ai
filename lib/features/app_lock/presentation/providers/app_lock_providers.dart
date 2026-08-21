import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/app_lock_account.dart';
import '../../data/app_lock_local_datasource.dart';
import '../../data/app_lock_repository_impl.dart';
import '../../domain/app_lock_repository.dart';
import 'app_lock_state.dart';

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppLockRepositoryImpl(AppLockLocalDataSource(prefs));
});

/// Drives the signup/PIN-entry gate. `build()` loads whatever account is
/// already on disk (if any) once per app process — `isUnlocked` then only
/// ever flips true in-memory via [unlock] or right after [createAccount], so
/// a fresh process always starts locked again.
final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockController extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final account = await ref.watch(appLockRepositoryProvider).load();
    return AppLockState(account: account);
  }

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<void> createAccount({required String name, required String pin}) async {
    final account = AppLockAccount(name: name.trim(), pinHash: _hashPin(pin));
    await ref.read(appLockRepositoryProvider).save(account);
    state = AsyncData(AppLockState(account: account, isUnlocked: true));
  }

  /// Returns whether the PIN matched. On a match, flips [AppLockState.isUnlocked]
  /// to true; on a mismatch, sets a readable error for the screen to show.
  bool unlock(String pin) {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) return false;

    final matches = account.pinHash == _hashPin(pin);
    state = AsyncData(
      matches
          ? current.copyWith(isUnlocked: true, errorMessage: null)
          : current.copyWith(errorMessage: 'Incorrect PIN. Try again.'),
    );
    return matches;
  }

  /// Updates the profile fields shown on the Profile screen. Rebuilds the
  /// account explicitly (rather than via `copyWith`) so passing `null` for
  /// [dob]/[email] unambiguously clears them.
  Future<void> updateProfile({required String name, DateTime? dob, String? email}) async {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) return;

    final trimmedEmail = email?.trim();
    final updated = AppLockAccount(
      name: name.trim(),
      pinHash: account.pinHash,
      dob: dob,
      email: (trimmedEmail == null || trimmedEmail.isEmpty) ? null : trimmedEmail,
    );
    await ref.read(appLockRepositoryProvider).save(updated);
    state = AsyncData(current.copyWith(account: updated));
  }

  /// Re-locks immediately, without waiting for the app process to restart —
  /// used by the "Lock now" action in Settings.
  void lock() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isUnlocked: false));
  }

  void dismissError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(errorMessage: null));
  }
}
