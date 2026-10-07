import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/features/backup/data/backup_service.dart';

/// exportToFile() calls getTemporaryDirectory(), which has no real platform
/// implementation to answer it under flutter_test — point it at the OS temp
/// dir directly instead of mocking the method channel by hand.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  late BackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.settings: jsonEncode({'googleSpeechApiKey': 'super-secret-key', 'hapticFeedback': false}),
      PrefsKeys.history: jsonEncode([]),
    });
    final prefs = await SharedPreferences.getInstance();
    service = BackupService(prefs);
  });

  test('exportToFile never includes the Google Cloud API key', () async {
    final file = await service.exportToFile();
    final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final settings = jsonDecode(payload['data']['settings'] as String) as Map<String, dynamic>;

    expect(settings.containsKey('googleSpeechApiKey'), isFalse);
    expect(settings['hapticFeedback'], false);
  });

  test('importFromFile round-trips everything except the stripped key', () async {
    final file = await service.exportToFile();

    SharedPreferences.setMockInitialValues({});
    final freshPrefs = await SharedPreferences.getInstance();
    final freshService = BackupService(freshPrefs);
    await freshService.importFromFile(file);

    final settings = jsonDecode(freshPrefs.getString(PrefsKeys.settings)!) as Map<String, dynamic>;
    expect(settings.containsKey('googleSpeechApiKey'), isFalse);
    expect(settings['hapticFeedback'], false);
  });

  test('importFromFile rejects a file from a different app', () async {
    SharedPreferences.setMockInitialValues({});
    final freshPrefs = await SharedPreferences.getInstance();
    final freshService = BackupService(freshPrefs);

    final file = await service.exportToFile();
    final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    payload['app'] = 'Some Other App';
    await file.writeAsString(jsonEncode(payload));

    expect(() => freshService.importFromFile(file), throwsA(anything));
  });
}
