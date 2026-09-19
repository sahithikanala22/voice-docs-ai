import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/providers/app_lock_providers.dart';
import 'package:ai_voice_docs/features/app_lock/presentation/widgets/account_avatar.dart';
import 'package:ai_voice_docs/features/backup/presentation/providers/backup_providers.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/domain/speech_engine.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

import '../providers/settings_providers.dart';
import '../widgets/palette_picker.dart';
import '../widgets/paper_style_picker.dart';
import '../widgets/sarvam_speech_settings.dart';
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
                      leading: AccountAvatar(
                        avatarPath: account?.avatarPath,
                        name: account?.name ?? '',
                        radius: 18,
                      ),
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
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Unlock with fingerprint / face'),
                      subtitle: Text(
                        biometricAvailable
                            ? 'Skip typing your PIN — the PIN still works as a backup'
                            : 'Set up a fingerprint or face unlock in your phone\'s settings first',
                      ),
                      value: settings.biometricUnlock && biometricAvailable,
                      onChanged: biometricAvailable
                          ? (value) => _toggleBiometric(context, ref, value)
                          : null,
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Palette',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.palette_outlined),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Palette',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      settings.useDynamicColor
                                          ? 'Turn off wallpaper colors below to pick a palette'
                                          : 'Choose your accent colors',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PalettePicker(
                            value: settings.palette,
                            enabled: !settings.useDynamicColor,
                            onChanged: controller.setPalette,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
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
                  title: 'Paper style',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Background texture for your pages',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PaperStylePicker(
                            value: settings.paperStyle,
                            backgroundPhotoPath: settings.backgroundPhotoPath,
                            onChanged: controller.setPaperStyle,
                            onPickPhoto: () => _pickBackgroundPhoto(context, ref, settings.backgroundPhotoPath),
                          ),
                          if (settings.backgroundPhotoPath != null) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _removeBackgroundPhoto(ref, settings.backgroundPhotoPath!),
                                child: const Text('Remove custom photo'),
                              ),
                            ),
                          ],
                        ],
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
                                value: SpeechEngine.sarvam,
                                label: Text('Sarvam AI'),
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
                                : 'Much stronger on Indian languages. Needs internet and your own API key; bills per use.',
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
                    if (settings.speechEngine == SpeechEngine.sarvam) ...[
                      const Divider(height: 1),
                      SarvamSpeechSettings(apiKey: settings.sarvamApiKey),
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

  /// Turning it on requires a successful biometric check first, so the
  /// switch can never be left on for a fingerprint/face that doesn't actually
  /// work; turning it off is immediate.
  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!enable) {
      await controller.setBiometricUnlock(false);
      return;
    }
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Confirm it\'s you to turn on biometric unlock');
    if (!context.mounted) return;
    if (ok) {
      await controller.setBiometricUnlock(true);
    } else {
      AppSnackbar.show(
        context,
        'Couldn\'t verify — biometric unlock stays off.',
        isError: true,
      );
    }
  }

  /// Photos are downscaled on the way in — a full-screen background never
  /// needs a multi-thousand-pixel camera photo, and this keeps storage and
  /// decode cost down since it's redrawn behind every screen in the app.
  static const _maxBackgroundPhotoDimension = 1600.0;
  static const _backgroundPhotoQuality = 85;

  Future<void> _pickBackgroundPhoto(BuildContext context, WidgetRef ref, String? currentPath) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: _maxBackgroundPhotoDimension,
        maxHeight: _maxBackgroundPhotoDimension,
        imageQuality: _backgroundPhotoQuality,
      );
      if (picked == null) return;

      final name = await ref.read(appBackgroundPhotoStoreProvider).import(picked.path);
      await ref.read(settingsControllerProvider.notifier).setCustomBackgroundPhoto(name);
      // Nothing references the old file once the new one is saved.
      if (currentPath != null) {
        await ref.read(appBackgroundPhotoStoreProvider).delete([currentPath]);
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
              ? 'Permission needed to add a photo. Allow it in your phone\'s settings.'
              : 'Could not add the photo: ${e.message ?? e.code}',
          isError: true,
        );
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.show(context, 'Could not add the photo: $e', isError: true);
    }
  }

  Future<void> _removeBackgroundPhoto(WidgetRef ref, String path) async {
    await ref.read(settingsControllerProvider.notifier).removeCustomBackgroundPhoto();
    await ref.read(appBackgroundPhotoStoreProvider).delete([path]);
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
        ..invalidate(diaryControllerProvider)
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
