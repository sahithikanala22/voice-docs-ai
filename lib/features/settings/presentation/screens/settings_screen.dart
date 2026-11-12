import 'dart:io';
import 'package:ai_voice_docs/features/text_to_speech/presentation/providers/tts_providers.dart';
import 'package:ai_voice_docs/core/privacy/local_data_service.dart';
import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/providers/notification_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/speech_providers.dart';
import 'package:ai_voice_docs/features/speech_to_text/presentation/providers/whisper_providers.dart';

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
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import '../widgets/accent_color_picker.dart';
import '../widgets/font_picker.dart';
import '../widgets/google_cloud_speech_settings.dart';
import '../widgets/whisper_speech_settings.dart';
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
                  title: 'Speech Recognition',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioGroup<SpeechEngine>(
                            groupValue: settings.speechEngine,
                            onChanged: (engine) async {
                              if (engine == null) return;
                              if (engine == SpeechEngine.googleCloud &&
                                  settings.speechEngine != engine) {
                                final accepted = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text(
                                      'Use Google Cloud speech?',
                                    ),
                                    content: const Text(
                                      'Audio is saved on this device before transcription. Google uploads use short chunks with retry checkpoints. Internet and your API key are required; charges may apply. Audio remains in Recover recordings until explicitly deleted. For offline audio capture, use Record meeting.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Use Google Cloud'),
                                      ),
                                    ],
                                  ),
                                );
                                if (accepted != true) return;
                              }
                              await controller.setSpeechEngine(engine);
                            },
                            child: Column(
                              children: [
                                for (final engine in SpeechEngine.values)
                                  RadioListTile<SpeechEngine>(
                                    value: engine,
                                    title: Text(engine.label),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            settings.speechEngine.privacyDescription,
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
                    if (settings.speechEngine == SpeechEngine.whisper)
                      const WhisperSpeechSettings(),
                    if (settings.speechEngine == SpeechEngine.googleCloud) ...[
                      const Divider(height: 1),
                      GoogleCloudSpeechSettings(
                        apiKey: settings.googleCloudApiKey,
                      ),
                    ],
                  ],
                ),
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
                      title: Text(account?.name ?? 'Local profile'),
                      subtitle: const Text(
                        'Local profile · stored on this device',
                      ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your appearance',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Dark is the default. System follows your device.',
                          ),
                          const SizedBox(height: 16),
                          ThemeModeSelector(
                            value: settings.themeMode,
                            onChanged: controller.setThemeMode,
                          ),
                        ],
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
                        'Includes photos and personal data in a readable file. Keep it private. PIN credentials and API keys are excluded.',
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
                      leading: const Icon(Icons.restore_rounded),
                      title: const Text('Recover recordings'),
                      subtitle: const Text(
                        'Play, export, transcribe or delete saved audio',
                      ),
                      onTap: () => context.push('/recover-recordings'),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Delete all local data'),
                      subtitle: const Text(
                        'Remove this profile and all app data on this device',
                      ),
                      onTap: () => _confirmDeleteAll(context, ref),
                    ),
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
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy policy'),
                      subtitle: const Text(
                        'Data use, storage, permissions and deletion',
                      ),
                      onTap: () => context.push('/privacy'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text(AppConstants.appName),
                      subtitle: Text(
                        'Version 1.0.0 · Speech-to-text & reminders',
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.wifi_off_rounded),
                      title: Text('Your data and speech privacy'),
                      subtitle: Text(
                        'History and reminders are stored on this device. Device speech services may use the internet. Google Cloud uploads your recordings for transcription. Playback depends on the selected device voice.',
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

    final controller = ref.read(settingsControllerProvider.notifier);
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
          'This replaces the history, folders, tasks, settings and images included in the backup. Your current PIN and API key are kept. This cannot be undone.',
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
        ..invalidate(diaryControllerProvider)
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

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('Delete all local data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Permanently delete your local profile, PIN, diary, history, tasks, settings, photos, saved recovery audio and internal backups, and cancel reminders. Files shared or saved outside this app are not deleted. Export anything you need first.',
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: busy
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(whisperModelStoreProvider)
                              .cancelAndWait();
                          await LocalDataService(
                            prefs: ref.read(sharedPreferencesProvider),
                            stopRecording: () async {
                              await ref
                                  .read(recordingCoordinatorProvider)
                                  .stop(cancelTranscription: true);
                              await ref
                                  .read(ttsControllerProvider.notifier)
                                  .stop();
                            },
                            cancelReminders: () => ref
                                .read(notificationServiceProvider)
                                .cancelAll(),
                          ).deleteAll();
                          ref
                            ..invalidate(historyControllerProvider)
                            ..invalidate(diaryControllerProvider)
                            ..invalidate(folderControllerProvider)
                            ..invalidate(taskControllerProvider)
                            ..invalidate(settingsControllerProvider)
                            ..invalidate(recordingCoordinatorProvider)
                            ..invalidate(speechProviderImplProvider)
                            ..invalidate(whisperModelControllerProvider)
                            ..invalidate(whisperModelStoreProvider)
                            ..invalidate(speechControllerProvider)
                            ..invalidate(ttsControllerProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          ref.invalidate(appLockControllerProvider);
                        } catch (_) {
                          if (dialogContext.mounted) {
                            update(() {
                              busy = false;
                              error =
                                  'Deletion could not finish. Some data may already be removed. Try again.';
                            });
                          }
                        }
                      },
                child: const Text('Permanently delete'),
              ),
            ],
          ),
        ),
      ),
    );
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
