import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/services/notification_service.dart';
import 'package:ai_voice_docs/features/history/data/history_item.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';

class FakeNotifications extends Fake implements NotificationService {
  final cancelled = <int>[];
  int cancelAllCalls = 0;
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late FakeNotifications notifications;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    notifications = FakeNotifications();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    await container.read(historyControllerProvider.future);
    await container.read(taskControllerProvider.future);
    await container.read(settingsControllerProvider.future);
    await container.read(folderControllerProvider.future);
  });
  tearDown(() => container.dispose());
  test(
    'clearing history cancels only entry reminders and keeps tasks',
    () async {
      final item = HistoryItem.voice(text: 'journal', languageCode: 'en');
      await container.read(historyControllerProvider.notifier).addEntry(item);
      await container
          .read(taskControllerProvider.notifier)
          .addTask('keep this task');
      await container.read(historyControllerProvider.notifier).clearAll();
      expect(notifications.cancelAllCalls, 0);
      expect(notifications.cancelled, [reminderNotificationId(item.id)]);
      expect(container.read(taskControllerProvider).value, hasLength(1));
    },
  );
  test(
    'folder deletion clears entry references and the current folder',
    () async {
      final folder = await container
          .read(folderControllerProvider.notifier)
          .addFolder('Diary');
      await container
          .read(settingsControllerProvider.notifier)
          .setCurrentFolderId(folder.id);
      await container
          .read(historyControllerProvider.notifier)
          .addEntry(
            HistoryItem.voice(
              text: 'keep',
              languageCode: 'en',
              folderId: folder.id,
            ),
          );
      await container
          .read(folderControllerProvider.notifier)
          .removeFolder(folder.id);
      expect(
        container.read(historyControllerProvider).value!.single.folderId,
        isNull,
      );
      expect(
        container.read(settingsControllerProvider).value!.currentFolderId,
        isNull,
      );
    },
  );
}
