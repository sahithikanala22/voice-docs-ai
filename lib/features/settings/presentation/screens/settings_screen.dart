import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/floating_dots_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/backup/presentation/providers/backup_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

import '../providers/settings_providers.dart';
import '../widgets/google_cloud_speech_settings.dart';
import '../widgets/settings_section.dart';
import '../widgets/theme_mode_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const GradientAppBarUnderline(),
      ),
      body: FloatingDotsBackground(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Could not load settings: $err')),
          data: (settings) {
            final account = ref.watch(appLockControllerProvider).value?.account;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SettingsSection(
                  title: 'Account',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(account?.name ?? 'Signed in'),
                      subtitle: const Text('View profile'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Lock now'),
                      subtitle: const Text(
                        'Require your PIN again immediately',
                      ),
                      onTap: () =>
                          ref.read(appLockControllerProvider.notifier).lock(),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Appearance',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ThemeModeSelector(
                        value: settings.themeMode,
                        onChanged: controller.setThemeMode,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.wallpaper_rounded),
                      title: const Text('Use wallpaper colors'),
                      subtitle: const Text(
                        'Material You — theme from your device wallpaper instead of app colors',
                      ),
                      value: settings.useDynamicColor,
                      onChanged: controller.setUseDynamicColor,
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Language',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.record_voice_over_outlined),
                      title: const Text('Default speech language'),
                      subtitle: Text(
                        languageByCode(settings.sourceLanguageCode).name,
                      ),
                      onTap: () => _pickLanguage(
                        context,
                        title: 'Default speech language',
                        selectedCode: settings.sourceLanguageCode,
                        onPicked: controller.setSourceLanguage,
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Speech Recognition',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedButton<SpeechEngine>(
                            segments: const [
                              ButtonSegment(
                                value: SpeechEngine.onDevice,
                                label: Text('On-device'),
                              ),
                              ButtonSegment(
                                value: SpeechEngine.googleCloud,
                                label: Text('Google Cloud'),
                              ),
                            ],
                            selected: {settings.speechEngine},
                            onSelectionChanged: (value) =>
                                controller.setSpeechEngine(value.first),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            settings.speechEngine == SpeechEngine.onDevice
                                ? 'Free and works offline. Reliability depends on your phone\'s own speech recognizer.'
                                : 'Generally more accurate. Needs internet and your own API key; bills per use past the free tier.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (settings.speechEngine == SpeechEngine.googleCloud) ...[
                      const Divider(height: 1),
                      GoogleCloudSpeechSettings(
                        apiKey: settings.googleCloudApiKey,
                      ),
                    ],
                  ],
                ),
                SettingsSection(
                  title: 'Behavior',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_rounded),
                      title: const Text('Haptic feedback'),
                      value: settings.hapticFeedback,
                      onChanged: controller.setHapticFeedback,
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Backup',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file_outlined),
                      title: const Text('Export backup'),
                      subtitle: const Text(
                        'Save history, folders, tasks & settings to a file',
                      ),
                      onTap: () => _exportBackup(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Restore from backup'),
                      subtitle: const Text(
                        'Replaces all current data on this device',
                      ),
                      onTap: () => _restoreBackup(context, ref),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Data',
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.delete_sweep_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Clear history',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () => _confirmClearHistory(context, ref),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'About',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text(AppConstants.appName),
                      subtitle: Text(
                        'Version 1.0.0 · Speech-to-text & reminders',
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.wifi_off_rounded),
                      title: Text('Works entirely offline'),
                      subtitle: Text(
                        'Voice, reminders and your saved history never leave this device.',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context, {
    required String title,
    required String selectedCode,
    required Future<void> Function(String) onPicked,
  }) async {
    final picked = await context.push<Language>(
      '/language-picker',
      extra: {'title': title, 'selectedCode': selectedCode},
    );
    if (picked != null) {
      await onPicked(picked.code);
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref.read(backupServiceProvider).exportToFile();
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Voice Docs AI backup');
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Could not create the backup.',
          isError: true,
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces all history, folders, tasks, settings and your PIN on this device with '
          'what\'s in the backup file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(backupServiceProvider).importFromFile(File(path));
      ref
        ..invalidate(historyControllerProvider)
        ..invalidate(folderControllerProvider)
        ..invalidate(taskControllerProvider)
        ..invalidate(settingsControllerProvider)
        ..invalidate(appLockControllerProvider);
      if (context.mounted) {
        AppSnackbar.show(context, 'Backup restored');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'That file could not be restored.',
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This removes every saved transcript. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(historyControllerProvider.notifier).clearAll();
      if (context.mounted) AppSnackbar.show(context, 'History cleared');
    }
  }
}
