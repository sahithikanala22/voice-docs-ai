import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/backup/presentation/providers/backup_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

import '../providers/app_lock_providers.dart';

/// First-launch screen: pick a name and a 4-digit PIN. Purely local — there
/// is no way to recover a forgotten PIN itself, since nothing here is
/// verified against a server, but this screen also doubles as the "welcome
/// back" step after a reset: if a pre-reset data snapshot is sitting on
/// disk, it's restored automatically once the new PIN is set (see
/// `_submit`).
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set up your name and a PIN to protect your history',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: const InputDecoration(
                        labelText: '4-digit PIN',
                        counterText: '',
                      ),
                      validator: (value) => (value == null || value.length != 4)
                          ? 'Enter a 4-digit PIN'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        counterText: '',
                      ),
                      validator: (value) => value != _pinController.text
                          ? 'PINs do not match'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Get started'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your name and PIN stay on this device only. A forgotten PIN can\'t be '
                      'recovered, but if you\'ve just reset the app, your history, tasks, and '
                      'folders will come back automatically once you\'re set up.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    await ref
        .read(appLockControllerProvider.notifier)
        .createAccount(name: _nameController.text, pin: _pinController.text);

    // If this signup follows a "Forgot PIN" reset, a snapshot of the old
    // history/tasks/folders/settings is still sitting on disk (the reset
    // only cleared SharedPreferences) — hand it all back now that there's a
    // new PIN to protect it, without touching the fresh account just
    // created. A brand-new install simply has no such file, so this is a
    // no-op for the normal first-run signup.
    final backupService = ref.read(backupServiceProvider);
    if (await backupService.hasAutoBackup()) {
      await backupService.restoreAutoBackupAfterReset();
      ref
        ..invalidate(historyControllerProvider)
        ..invalidate(folderControllerProvider)
        ..invalidate(taskControllerProvider)
        ..invalidate(settingsControllerProvider);
      if (mounted) {
        AppSnackbar.show(
          context,
          'Your previous history, tasks, and folders were restored',
        );
      }
    }

    // On success, the router's redirect callback moves off this screen
    // automatically once appLockControllerProvider reports isUnlocked.
    if (mounted) setState(() => _isSubmitting = false);
  }
}
