import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/theme/app_theme.dart';
import 'package:ai_voice_docs/core/theme/paper_style.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/backup/presentation/providers/backup_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

import '../providers/settings_providers.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/font_picker.dart';
import '../widgets/google_cloud_speech_settings.dart';
import '../widgets/paper_style_picker.dart';
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
      body: PaperBackground(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Could not load settings: $err')),
          data: (settings) {
            final account = ref.watch(appLockControllerProvider).value?.account;
            final biometricAvailable =
                ref.watch(biometricAvailableProvider).value ?? false;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SettingsSection(
                  title: 'Account',
                  children: [
                    ListTile(
                      leading:
                          (account?.avatarPath != null &&
                              File(account!.avatarPath!).existsSync())
                          ? CircleAvatar(
                              backgroundImage: FileImage(
                                File(account.avatarPath!),
                              ),
                            )
                          : const Icon(Icons.person_outline_rounded),
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
                    if (biometricAvailable) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint_rounded),
                        title: const Text('Unlock with biometrics'),
                        subtitle: const Text(
                          'Use your fingerprint or face alongside your PIN',
                        ),
                        value: settings.biometricUnlockEnabled,
                        onChanged: controller.setBiometricUnlockEnabled,
                      ),
                    ],
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
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Palette',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            settings.useDynamicColor
                                ? 'Turn off "Use wallpaper colors" to pick a color here'
                                : 'Choose your accent color',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Opacity(
                            opacity: settings.useDynamicColor ? 0.4 : 1,
                            child: IgnorePointer(
                              ignoring: settings.useDynamicColor,
                              child: AccentColorPicker(
                                value: settings.accentColorValue == null
                                    ? null
                                    : Color(settings.accentColorValue!),
                                onChanged: controller.setAccentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paper Style',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Background texture for your pages',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          PaperStylePicker(
                            value: settings.paperStyle,
                            onChanged: controller.setPaperStyle,
                            customImagePath: settings.customBackgroundPath,
                            onPickCustomImage: () =>
                                _pickCustomBackground(context, ref),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.font_download_outlined),
                      title: const Text('Choose your font'),
                      subtitle: Text(
                        AppTheme.fontChoices
                            .firstWhere(
                              (c) => c.family == settings.fontFamily,
                              orElse: () => AppTheme.fontChoices.first,
                            )
                            .label,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickFont(
                        context,
                        settings.fontFamily,
                        controller.setFontFamily,
                      ),
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
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.widgets_outlined),
                      title: const Text('Add "New voice entry" widget'),
                      subtitle: const Text(
                        'A home-screen shortcut that starts recording immediately',
                      ),
                      onTap: () => _addHomeWidget(context),
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

  Future<void> _addHomeWidget(BuildContext context) async {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!supported) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Long-press your home screen, choose Widgets, then find Voice Docs AI to add it.',
        );
      }
      return;
    }
    await HomeWidget.requestPinWidget(androidName: 'VoiceWidgetProvider');
  }

  Future<void> _pickCustomBackground(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Could not open ${source == ImageSource.camera ? 'the camera' : 'the gallery'}.',
          isError: true,
        );
      }
      return;
    }
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final destFile = File('${dir.path}/custom_background.jpg');
    if (await destFile.exists()) await destFile.delete();
    await File(picked.path).copy(destFile.path);

    final controller = ref.read(settingsControllerProvider.notifier);
    await controller.setCustomBackgroundPath(destFile.path);
    await controller.setPaperStyle(PaperStyle.customImage);
  }

  Future<void> _pickFont(
    BuildContext context,
    String? currentFamily,
    Future<void> Function(String?) onPicked,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: FontPicker(
              value: currentFamily,
              onChanged: (family) {
                onPicked(family);
                Navigator.pop(sheetContext);
              },
            ),
          ),
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
