import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/constants/supported_languages.dart';
import 'package:ai_voice_docs/core/models/language.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/gradient_app_bar_underline.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';

import '../providers/settings_providers.dart';
import '../widgets/settings_section.dart';
import '../widgets/theme_mode_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), bottom: const GradientAppBarUnderline()),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load settings: $err')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
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
                ],
              ),
              SettingsSection(
                title: 'Language',
                children: [
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: const Text('Default speech language'),
                    subtitle: Text(languageByCode(settings.sourceLanguageCode).name),
                    onTap: () => _pickLanguage(
                      context,
                      title: 'Default speech language',
                      selectedCode: settings.sourceLanguageCode,
                      onPicked: controller.setSourceLanguage,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.translate_outlined),
                    title: const Text('Default translate-to language'),
                    subtitle: Text(languageByCode(settings.targetLanguageCode).name),
                    onTap: () => _pickLanguage(
                      context,
                      title: 'Default translate-to language',
                      selectedCode: settings.targetLanguageCode,
                      onPicked: controller.setTargetLanguage,
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Behavior',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Auto-play translations'),
                    subtitle: const Text('Speak the translated text automatically'),
                    value: settings.autoPlayTranslationTts,
                    onChanged: controller.setAutoPlayTranslationTts,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Haptic feedback'),
                    value: settings.hapticFeedback,
                    onChanged: controller.setHapticFeedback,
                  ),
                ],
              ),
              SettingsSection(
                title: 'Data',
                children: [
                  ListTile(
                    leading: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text('Clear history', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    subtitle: Text('Version 1.0.0 · Speech-to-text, translation & TTS'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.wifi_off_rounded),
                    title: Text('Voice & speech work offline'),
                    subtitle: Text('Translation requires an internet connection.'),
                  ),
                ],
              ),
            ],
          );
        },
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

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('This removes every saved transcript and translation. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(historyControllerProvider.notifier).clearAll();
      if (context.mounted) AppSnackbar.show(context, 'History cleared');
    }
  }
}
