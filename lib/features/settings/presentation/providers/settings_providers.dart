import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';

import '../../data/settings_local_datasource.dart';
import '../../data/settings_repository_impl.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(SettingsLocalDataSource(prefs));
});

/// The single source of truth for user preferences. Every mutator persists
/// immediately so settings survive an app restart with no explicit "save"
/// step.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    final current = state.value ?? const AppSettings();
    final updated = transform(current);
    state = AsyncData(updated);
    await ref.read(settingsRepositoryProvider).save(updated);
  }

  Future<void> setThemeMode(ThemeMode mode) => _update((s) => s.copyWith(themeMode: mode));

  Future<void> setSourceLanguage(String code) => _update((s) => s.copyWith(sourceLanguageCode: code));

  Future<void> setTargetLanguage(String code) => _update((s) => s.copyWith(targetLanguageCode: code));

  Future<void> setAutoPlayTranslationTts(bool value) =>
      _update((s) => s.copyWith(autoPlayTranslationTts: value));

  Future<void> setHapticFeedback(bool value) => _update((s) => s.copyWith(hapticFeedback: value));

  Future<void> setCurrentFolderId(String? folderId) =>
      _update((s) => s.copyWith(currentFolderId: folderId));
}
