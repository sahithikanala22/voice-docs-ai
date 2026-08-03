import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voxi_translate/core/providers/core_providers.dart';

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
  }

  Future<void> removeEntry(String id) async {
    await ref.read(historyRepositoryProvider).remove(id);
    state = AsyncData(await ref.read(historyRepositoryProvider).getAll());
  }

  Future<void> clearAll() async {
    await ref.read(historyRepositoryProvider).clear();
    state = const AsyncData([]);
  }
}
