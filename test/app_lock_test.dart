import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/domain/app_lock_repository.dart';

class _AccountRepository implements AppLockRepository {
  AppLockAccount? account = AppLockAccount(
    name: 'Owner',
    pinHash: sha256.convert(utf8.encode('1234')).toString(),
  );
  @override
  Future<AppLockAccount?> load() async => account;
  @override
  Future<void> save(AppLockAccount value) async {
    account = value;
  }

  @override
  Future<void> clear() async {
    account = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PIN cooldown persists when the controller is recreated', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _AccountRepository();
    ProviderContainer create() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockRepositoryProvider.overrideWithValue(repo),
      ],
    );
    var container = create();
    await container.read(appLockControllerProvider.future);
    for (var i = 0; i < 5; i++) {
      expect(
        await container.read(appLockControllerProvider.notifier).unlock('0000'),
        isFalse,
      );
    }
    container.dispose();
    container = create();
    addTearDown(container.dispose);
    await container.read(appLockControllerProvider.future);
    expect(
      await container.read(appLockControllerProvider.notifier).unlock('1234'),
      isFalse,
    );
    expect(
      container.read(appLockControllerProvider).value!.isUnlocked,
      isFalse,
    );
    expect(
      container.read(appLockControllerProvider).value!.errorMessage,
      contains('Too many attempts'),
    );
    final attempts =
        jsonDecode((await PrivateStore(prefs).read('voxi.lock_attempts.v1'))!)
            as Map;
    expect(attempts['failures'], 5);
  });
  test(
    'a successful legacy PIN unlock migrates to salted PBKDF2',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _AccountRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appLockControllerProvider.future);
      expect(
        await container.read(appLockControllerProvider.notifier).unlock('1234'),
        isTrue,
      );
      expect(repo.account!.pinHash, startsWith('pbkdf2-sha256:600000:'));
      expect(
        container.read(appLockControllerProvider).value!.isUnlocked,
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
