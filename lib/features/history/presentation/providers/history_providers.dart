import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/core/services/notification_service.dart';

import '../../data/history_item.dart';
import '../../data/history_local_datasource.dart';
import '../../data/history_repository_impl.dart';
import '../../domain/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryRepositoryImpl(HistoryLocalDataSource(prefs));
});

/// Holds the full, newest-first history list and exposes mutation methods
/// that immediately persist and refresh state — the UI never talks to the
/// repository directly.
final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<HistoryItem>>(HistoryController.new);

class HistoryController extends AsyncNotifier<List<HistoryItem>> {
  @override
  Future<List<HistoryItem>> build() {
    return ref.watch(historyRepositoryProvider).getAll();
  }

  Future<void> addEntry(HistoryItem item) async {
    await ref.read(historyRepositoryProvider).add(item);
    state = AsyncData(await ref.read(historyRepositoryProvider).getAll());
    if (item.reminderAt != null) {
      await _scheduleReminder(item);
    }
  }

  Future<void> removeEntry(String id) async {
    await ref.read(historyRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(historyRepositoryProvider).getAll());
    await ref.read(notificationServiceProvider).cancel(reminderNotificationId(id));
  }

  Future<void> clearAll() async {
    await ref.read(historyRepositoryProvider).clear();
    state = const AsyncData([]);
    await ref.read(notificationServiceProvider).cancelAll();
  }

  Future<void> moveToFolder(String id, String? folderId) async {
    await ref.read(historyRepositoryProvider).updateFolder(id, folderId);
    state = AsyncData(await ref.read(historyRepositoryProvider).getAll());
  }

  /// Sets, replaces, or clears (pass null) the reminder on an already-saved
  /// entry — used from the History detail sheet, separately from setting one
  /// at creation time in the Add Entry sheet.
  Future<void> setReminder(String id, DateTime? reminderAt) async {
    await ref.read(historyRepositoryProvider).updateReminder(id, reminderAt);
    state = AsyncData(await ref.read(historyRepositoryProvider).getAll());
    final notificationId = reminderNotificationId(id);
    if (reminderAt == null) {
      await ref.read(notificationServiceProvider).cancel(notificationId);
      return;
    }
    final item = state.value?.firstWhere((e) => e.id == id);
    if (item != null) await _scheduleReminder(item);
  }

  Future<void> _scheduleReminder(HistoryItem item) async {
    final reminderAt = item.reminderAt;
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) return;
    final notificationService = ref.read(notificationServiceProvider);
    final granted = await notificationService.requestPermission();
    if (!granted) return;
    await notificationService.scheduleReminder(
      id: reminderNotificationId(item.id),
      title: 'Reminder',
      body: item.sourceText,
      scheduledDate: reminderAt,
    );
  }
}
