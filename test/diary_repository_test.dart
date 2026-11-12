import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/storage/private_store.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/features/backup/data/backup_service.dart';
import 'package:ai_voice_docs/features/diary/data/diary_entry.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:ai_voice_docs/features/settings/domain/app_settings.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late ProviderContainer container;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(diaryControllerProvider.future);
  });
  tearDown(() => container.dispose());

  DiaryEntry entry(
    String id,
    DateTime date, {
    String body = 'Personal thoughts',
    List<String> photos = const [],
  }) => DiaryEntry(
    id: id,
    date: date,
    createdAt: date,
    updatedAt: date,
    title: 'A useful day',
    body: body,
    photos: photos,
    mood: DiaryMood.calm,
    pageStyle: DiaryPageStyle.warm,
  );

  test(
    'diary saves are serialized, encrypted, backdated, and editable',
    () async {
      final controller = container.read(diaryControllerProvider.notifier);
      await Future.wait([
        controller.save(entry('earlier', DateTime(2026, 10, 12))),
        controller.save(entry('today', DateTime(2026, 10, 20))),
      ]);
      expect(
        container.read(diaryControllerProvider).requireValue.map((e) => e.id),
        ['today', 'earlier'],
      );
      final ciphertext = prefs.getString(PrefsKeys.diary)!;
      expect(ciphertext, isNot(contains('Personal thoughts')));
      expect(jsonDecode(ciphertext)['encrypted'], 1);
      await controller.save(
        entry('earlier', DateTime(2026, 10, 12), body: 'Edited words'),
      );
      container.invalidate(diaryControllerProvider);
      final reloaded = await container.read(diaryControllerProvider.future);
      expect(reloaded, hasLength(2));
      expect(reloaded.last.body, 'Edited words');
      expect(reloaded.last.mood, DiaryMood.calm);
      expect(reloaded.last.pageStyle, DiaryPageStyle.warm);
      await container.read(diaryControllerProvider.notifier).delete('today');
      expect(
        container.read(diaryControllerProvider).requireValue.single.id,
        'earlier',
      );
    },
  );

  test(
    'portable backup restores diary text, mood, date, and actual photo bytes',
    () async {
      final previousPaths = PathProviderPlatform.instance;
      final directory = await Directory.systemTemp.createTemp('diary_backup_');
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      PathProviderPlatform.instance = FakePaths(directory.path);
      final photo = await File(
        'assets/icon/icon.png',
      ).copy('${directory.path}/photo.png');
      await container
          .read(diaryControllerProvider.notifier)
          .save(
            entry('with-photo', DateTime(2026, 10, 12), photos: [photo.path]),
          );
      final service = BackupService(prefs);
      final backup = await service.exportToFile();
      final destination = await Directory(
        '${directory.path}/restored',
      ).create();
      PathProviderPlatform.instance = FakePaths(destination.path);
      await PrivateStore(prefs).write(PrefsKeys.diary, '[]');
      await service.importFromFile(backup);
      container.invalidate(diaryControllerProvider);
      final restored = (await container.read(
        diaryControllerProvider.future,
      )).single;
      expect(restored.date, DateTime(2026, 10, 12));
      expect(restored.mood, DiaryMood.calm);
      expect(restored.photos.single, isNot(photo.path));
      expect(
        await File(restored.photos.single).readAsBytes(),
        await photo.readAsBytes(),
      );
    },
  );

  test(
    'first launch and absent stored theme use dark, explicit System is preserved',
    () {
      expect(const AppSettings().themeMode, ThemeMode.dark);
      expect(AppSettings.fromJson({}).themeMode, ThemeMode.dark);
      expect(
        AppSettings.fromJson({'themeMode': 'system'}).themeMode,
        ThemeMode.system,
      );
    },
  );

  test('brand primary text has readable contrast in both appearances', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final a = theme.colorScheme.primary.computeLuminance();
      final b = theme.colorScheme.onPrimary.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
