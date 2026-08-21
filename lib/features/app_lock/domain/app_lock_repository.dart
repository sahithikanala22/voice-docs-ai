import '../data/app_lock_account.dart';

abstract class AppLockRepository {
  Future<AppLockAccount?> load();

  Future<void> save(AppLockAccount account);

  /// Wipes the account only — used by the "forgot PIN" reset flow. Wiping
  /// history/folders/settings too is the caller's job, since this repository
  /// only owns the account record.
  Future<void> clear();
}
