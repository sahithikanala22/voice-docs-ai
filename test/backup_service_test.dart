import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/features/backup/data/backup_service.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'package:ai_voice_docs/features/app_lock/data/app_lock_account.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late SharedPreferences prefs;
  late PrivateStore store;
  late BackupService service;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('voice_backup_test_');
    PathProviderPlatform.instance = FakePaths(dir.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PrivateStore(prefs);
    service = BackupService(prefs);
    await store.write(
      PrefsKeys.history,
      jsonEncode([
        HistoryItem.voice(text: 'private diary', languageCode: 'en').toJson(),
      ]),
    );
    await store.write(PrefsKeys.folders, '[]');
    await store.write(PrefsKeys.tasks, '[]');
    await store.write(
      PrefsKeys.settings,
      jsonEncode(
        const AppSettings(googleCloudApiKey: 'secret-api-key').toJson(),
      ),
    );
    await store.write(
      PrefsKeys.appLockAccount,
      jsonEncode(
        const AppLockAccount(
          name: 'Original',
          pinHash: 'secret-pin-hash',
        ).toJson(),
      ),
    );
  });
  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test(
    'portable backup includes image bytes and excludes credentials',
    () async {
      final image = await File(
        'assets/icon/icon.png',
      ).copy('${dir.path}/avatar.png');
      await store.write(
        PrefsKeys.appLockAccount,
        jsonEncode(
          AppLockAccount(
            name: 'Original',
            pinHash: 'secret-pin-hash',
            avatarPath: image.path,
          ).toJson(),
        ),
      );
      await store.write(
        PrefsKeys.settings,
        jsonEncode(
          AppSettings(
            googleCloudApiKey: 'secret-api-key',
            customBackgroundPath: image.path,
          ).toJson(),
        ),
      );
      final file = await service.exportToFile();
      final text = await file.readAsString();
      expect(text, isNot(contains('secret-api-key')));
      expect(text, isNot(contains('secret-pin-hash')));
      final payload = jsonDecode(text) as Map;
      expect(payload['attachments'], hasLength(1)); // Deduplicated images.

      final destination = await Directory('${dir.path}/new_phone').create();
      PathProviderPlatform.instance = FakePaths(destination.path);
      await store.write(
        PrefsKeys.appLockAccount,
        jsonEncode(
          const AppLockAccount(
            name: 'New owner',
            pinHash: 'current-pin',
          ).toJson(),
        ),
      );
      await store.write(
        PrefsKeys.settings,
        jsonEncode(
          const AppSettings(googleCloudApiKey: 'current-key').toJson(),
        ),
      );
      await service.importFromFile(file);
      final account = AppLockAccount.fromJson(
        jsonDecode((await store.read(PrefsKeys.appLockAccount))!)
            as Map<String, dynamic>,
      );
      final settings = AppSettings.fromJson(
        jsonDecode((await store.read(PrefsKeys.settings))!)
            as Map<String, dynamic>,
      );
      expect(account.pinHash, 'current-pin');
      expect(settings.googleCloudApiKey, 'current-key');
      expect(account.avatarPath, startsWith(destination.path));
      expect(account.avatarPath, isNot(image.path));
      expect(
        await File(account.avatarPath!).readAsBytes(),
        await image.readAsBytes(),
      );
      expect(
        await File(settings.customBackgroundPath!).readAsBytes(),
        await image.readAsBytes(),
      );
    },
  );

  test(
    'internal recovery snapshot is encrypted and preserves the new account',
    () async {
      await service.saveAutoBackupBeforeReset();
      final snapshot = File('${dir.path}/auto_backup_before_reset.json');
      expect(await snapshot.readAsString(), isNot(contains('private diary')));
      await prefs.clear();
      await store.write(
        PrefsKeys.appLockAccount,
        jsonEncode(
          const AppLockAccount(name: 'New', pinHash: 'new-pin').toJson(),
        ),
      );
      await service.restoreAutoBackupAfterReset();
      expect(await store.read(PrefsKeys.history), contains('private diary'));
      expect(await store.read(PrefsKeys.appLockAccount), contains('new-pin'));
      expect(await service.hasAutoBackup(), isFalse);
    },
  );

  for (final damage in [
    'version',
    'invalid settings',
    'duplicate record',
    'missing image',
    'corrupt image',
  ]) {
    test('rejects $damage before changing any preferences', () async {
      final file = await service.exportToFile();
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>;
      switch (damage) {
        case 'version':
          payload['formatVersion'] = 999;
        case 'invalid settings':
          data['settings'] = '{"themeMode":17}';
        case 'duplicate record':
          final rows = jsonDecode(data['history'] as String) as List;
          data['history'] = jsonEncode([rows.first, rows.first]);
        case 'missing image':
          data['settings'] = jsonEncode({
            'customBackgroundPath': 'backup-attachment:${'a' * 64}',
          });
        case 'corrupt image':
          payload['attachments'] = {
            'a' * 64: {
              'sha256': 'a' * 64,
              'bytes': base64Encode([1, 2, 3]),
            },
          };
      }
      await file.writeAsString(jsonEncode(payload));
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      await expectLater(service.importFromFile(file), throwsA(anything));
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    });
  }
  test(
    'accepts v1 data while dropping stale image paths and keeping the PIN',
    () async {
      final file = File('${dir.path}/legacy.json');
      await file.writeAsString(
        jsonEncode({
          'app': AppConstants.appName,
          'formatVersion': 1,
          'data': {
            'history': '[]',
            'settings': jsonEncode(
              const AppSettings(
                customBackgroundPath: '/old/phone/photo.jpg',
                googleCloudApiKey: 'old-secret',
              ).toJson(),
            ),
            'appLockAccount': jsonEncode(
              const AppLockAccount(
                name: 'Legacy',
                pinHash: 'old-pin',
                avatarPath: '/old/avatar.jpg',
              ).toJson(),
            ),
          },
        }),
      );
      await service.importFromFile(file);
      final settings =
          jsonDecode((await store.read(PrefsKeys.settings))!) as Map;
      final account =
          jsonDecode((await store.read(PrefsKeys.appLockAccount))!) as Map;
      expect(settings['customBackgroundPath'], isNull);
      expect(settings['googleCloudApiKey'], 'secret-api-key');
      expect(account['pinHash'], 'secret-pin-hash');
      expect(account['avatarPath'], isNull);
    },
  );
}
