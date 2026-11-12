import 'package:flutter/material.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/backup/presentation/providers/backup_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';

import '../providers/app_lock_providers.dart';

/// Shown on every fresh app launch until the correct PIN is entered —
/// `AppLockState.isUnlocked` only lives in memory, so this always reappears
/// after the app process is fully restarted.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  final _pinController = TextEditingController();

  /// Guards the auto-prompt so it fires once per time this screen appears,
  /// not on every rebuild (`build()` re-runs a lot from `ref.watch`) — the
  /// button below still lets the user retry biometrics manually any time.
  bool _biometricAutoPromptSent = false;
  bool _submitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider).value;
    final name = lockState?.account?.name ?? '';
    final biometricEnabled =
        ref.watch(settingsControllerProvider).value?.biometricUnlockEnabled ??
        false;

    ref.listen(appLockControllerProvider, (previous, next) {
      final error = next.value?.errorMessage;
      if (error != null && error != previous?.value?.errorMessage) {
        AppSnackbar.show(context, error, isError: true);
        _pinController.clear();
      }
    });

    if (biometricEnabled && !_biometricAutoPromptSent) {
      _biometricAutoPromptSent = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryBiometricUnlock(),
      );
    }

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your PIN to continue',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    enabled: !_submitting,
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Unlocking…'),
                            ],
                          )
                        : const Text('Unlock'),
                  ),
                  if (biometricEnabled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _tryBiometricUnlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock with biometrics'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => _confirmReset(context),
                    child: const Text('Forgot PIN?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_pinController.text.length != 4 && _pinController.text.length != 6) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(appLockControllerProvider.notifier)
          .unlock(_pinController.text);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not verify your PIN. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _tryBiometricUnlock() async {
    await ref.read(appLockControllerProvider.notifier).unlockWithBiometrics();
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app data?'),
        content: const Text(
          'Verify your device passcode or biometrics to set a new app PIN. Your history, tasks and folders will be preserved. Without device verification, existing data stays locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final verified = await ref
          .read(biometricAuthServiceProvider)
          .authenticateRecovery();
      if (!verified || !context.mounted) return;
      // Snapshot everything to a file first — SharedPreferences.clear()
      // below only empties the prefs store, so this survives the wipe and
      // lets SignupScreen hand it all back once a new PIN is set up.
      await ref.read(backupServiceProvider).saveAutoBackupBeforeReset();
      await ref.read(sharedPreferencesProvider).clear();
      ref.invalidate(historyControllerProvider);
      ref.invalidate(diaryControllerProvider);
      ref.invalidate(folderControllerProvider);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(appLockControllerProvider);
    }
  }
}
