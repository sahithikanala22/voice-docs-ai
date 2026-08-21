import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_lock_account.freezed.dart';
part 'app_lock_account.g.dart';

/// The device-local "account" that gates the app — just a display name and
/// a hashed PIN, with nothing sent anywhere. This is a screen lock, not
/// server-verified identity: it protects the app's data from someone who
/// picks up an already-unlocked phone, not from someone with full device
/// access (e.g. anyone who could already read the phone's app storage).
@freezed
class AppLockAccount with _$AppLockAccount {
  const factory AppLockAccount({
    required String name,
    required String pinHash,
    DateTime? dob,
    String? email,
  }) = _AppLockAccount;

  factory AppLockAccount.fromJson(Map<String, dynamic> json) => _$AppLockAccountFromJson(json);
}
