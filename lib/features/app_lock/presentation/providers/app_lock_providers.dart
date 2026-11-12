import 'dart:convert';

import 'dart:math';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import '../../data/pin_hasher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/app_lock_account.dart';
import '../../data/app_lock_local_datasource.dart';
import '../../data/app_lock_repository_impl.dart';
import '../../data/biometric_auth_service.dart';
import '../../domain/app_lock_repository.dart';
import 'app_lock_state.dart';

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppLockRepositoryImpl(AppLockLocalDataSource(prefs));
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => BiometricAuthService(),
);

/// Whether this device can actually do biometric auth — gates whether the
/// Settings toggle even appears, since offering it on hardware with nothing
/// enrolled would just fail every time.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricAuthServiceProvider).isAvailable();
});

/// Drives the signup/PIN-entry gate. `build()` loads whatever account is
/// already on disk (if any) once per app process — `isUnlocked` then only
/// ever flips true in-memory via [unlock] or right after [createAccount], so
/// a fresh process always starts locked again.
final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
      AppLockController.new,
    );

class AppLockController extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final account = await ref.watch(appLockRepositoryProvider).load();
    return AppLockState(account: account);
  }

  static const _attemptsKey = 'voxi.lock_attempts.v1';
  bool _checking = false;
  int _lockEpoch = 0;
  final _hasher = const PinHasher();

  Future<void> createAccount({
    required String name,
    required String pin,
  }) async {
    final epoch = _lockEpoch;
    final account = AppLockAccount(
      name: name.trim(),
      pinHash: await _hasher.hash(pin),
    );
    await ref.read(appLockRepositoryProvider).save(account);
    state = AsyncData(
      AppLockState(account: account, isUnlocked: epoch == _lockEpoch),
    );
  }

  /// Returns whether the PIN matched. On a match, flips [AppLockState.isUnlocked]
  /// to true; on a mismatch, sets a readable error for the screen to show.
  Future<bool> unlock(String pin) async {
    final current = state.value;
    final account = current?.account;
    if (_checking || current == null || account == null) return false;
    _checking = true;
    final epoch = _lockEpoch;
    try {
      final store = PrivateStore(ref.read(sharedPreferencesProvider));
      final raw = await store.read(_attemptsKey);
      final attempts = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final blockedUntil = attempts['blockedUntil'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < blockedUntil) {
        state = AsyncData(
          current.copyWith(
            errorMessage:
                'Too many attempts. Try again in ${((blockedUntil - now) / 1000).ceil()} seconds.',
          ),
        );
        return false;
      }
      final failures = (attempts['failures'] as int? ?? 0) + 1;
      final delaySeconds = failures >= 5
          ? min(900, 30 * pow(2, min(failures - 5, 5)).toInt())
          : 0;
      await store.write(
        _attemptsKey,
        jsonEncode({
          'failures': failures,
          'blockedUntil': now + delaySeconds * 1000,
        }),
      );
      final matches = await _hasher.verify(pin, account.pinHash);
      if (matches) {
        var updated = account;
        if (!account.pinHash.startsWith('pbkdf2-sha256:')) {
          updated = account.copyWith(pinHash: await _hasher.hash(pin));
          await ref.read(appLockRepositoryProvider).save(updated);
        }
        await ref.read(sharedPreferencesProvider).remove(_attemptsKey);
        if (epoch != _lockEpoch) return false;
        state = AsyncData(
          current.copyWith(
            account: updated,
            isUnlocked: true,
            errorMessage: null,
          ),
        );
      } else {
        state = AsyncData(
          current.copyWith(
            isUnlocked: false,
            errorMessage: delaySeconds > 0
                ? 'Too many attempts. Try again in $delaySeconds seconds.'
                : 'Incorrect PIN. Try again.',
          ),
        );
      }
      return matches;
    } finally {
      _checking = false;
    }
  }

  /// Unlocks after a successful biometric check — no PIN involved, since
  /// the OS's own fingerprint/face prompt already did the authenticating.
  Future<void> unlockWithBiometrics() async {
    final epoch = _lockEpoch;
    final success = await ref.read(biometricAuthServiceProvider).authenticate();
    final current = state.value;
    if (!success ||
        epoch != _lockEpoch ||
        current == null ||
        current.account == null) {
      return;
    }
    await ref.read(sharedPreferencesProvider).remove(_attemptsKey);
    state = AsyncData(current.copyWith(isUnlocked: true, errorMessage: null));
  }

  /// Updates the profile fields shown on the Profile screen. Rebuilds the
  /// account explicitly (rather than via `copyWith`) so passing `null` for
  /// [dob]/[email] unambiguously clears them. [avatarPath] is left
  /// unchanged when omitted — it's updated separately via [updateAvatar]
  /// since picking a photo doesn't go through the rest of this form.
  Future<void> updateProfile({
    required String name,
    DateTime? dob,
    String? email,
  }) async {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) return;

    final trimmedEmail = email?.trim();
    final updated = AppLockAccount(
      name: name.trim(),
      pinHash: account.pinHash,
      dob: dob,
      email: (trimmedEmail == null || trimmedEmail.isEmpty)
          ? null
          : trimmedEmail,
      avatarPath: account.avatarPath,
    );
    await ref.read(appLockRepositoryProvider).save(updated);
    state = AsyncData((state.value ?? current).copyWith(account: updated));
  }

  /// Sets or clears (pass `null`) the path to the profile picture.
  Future<void> updateAvatar(String? avatarPath) async {
    final current = state.value;
    final account = current?.account;
    if (current == null || account == null) return;

    final updated = account.copyWith(avatarPath: avatarPath);
    await ref.read(appLockRepositoryProvider).save(updated);
    state = AsyncData((state.value ?? current).copyWith(account: updated));
  }

  /// Re-locks immediately, without waiting for the app process to restart —
  /// used by the "Lock now" action in Settings.
  void lock() {
    _lockEpoch++;
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
