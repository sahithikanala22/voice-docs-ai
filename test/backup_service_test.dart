import 'dart:io';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/features/backup/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real path_provider has no Dart-only test implementation — this stands in
/// so `getApplicationDocumentsDirectory()` resolves to an actual temp
/// directory instead of throwing `MissingPluginException`.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backup_service_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('BackupService auto-backup (Forgot PIN recovery)', () {
    test(
      'restores history/tasks/folders/settings but not the account after a reset',
      () async {
        SharedPreferences.setMockInitialValues({
          PrefsKeys.history: '"old-history"',
          PrefsKeys.settings: '"old-settings"',
          PrefsKeys.folders: '"old-folders"',
          PrefsKeys.tasks: '"old-tasks"',
          PrefsKeys.appLockAccount: '"old-account-with-forgotten-pin"',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = BackupService(prefs);

        // User forgets their PIN and resets: snapshot first, then the app
        // wipes prefs exactly like the real reset flow does.
        await service.saveAutoBackupBeforeReset();
        await prefs.clear();

        expect(await service.hasAutoBackup(), isTrue);
        expect(prefs.getString(PrefsKeys.history), isNull);

        // Signup writes a brand-new account under a new PIN...
        await prefs.setString(
          PrefsKeys.appLockAccount,
          '"new-account-with-new-pin"',
        );

        // ...then the old data is handed back without touching that new PIN.
        await service.restoreAutoBackupAfterReset();

        expect(prefs.getString(PrefsKeys.history), '"old-history"');
        expect(prefs.getString(PrefsKeys.settings), '"old-settings"');
        expect(prefs.getString(PrefsKeys.folders), '"old-folders"');
        expect(prefs.getString(PrefsKeys.tasks), '"old-tasks"');
        expect(
          prefs.getString(PrefsKeys.appLockAccount),
          '"new-account-with-new-pin"',
        );

        // One-shot: doesn't linger to be silently reapplied on some later run.
        expect(await service.hasAutoBackup(), isFalse);
      },
    );

    test('a normal fresh install has no auto-backup to restore', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = BackupService(prefs);

      expect(await service.hasAutoBackup(), isFalse);
    });
  });
}
