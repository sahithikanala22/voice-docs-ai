import 'package:flutter/material.dart';
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
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 4,
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
                  FilledButton(onPressed: _submit, child: const Text('Unlock')),
                  if (biometricEnabled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _tryBiometricUnlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock with biometrics'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _confirmReset(context),
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

  void _submit() {
    if (_pinController.text.length != 4) return;
    ref.read(appLockControllerProvider.notifier).unlock(_pinController.text);
  }

  Future<void> _tryBiometricUnlock() async {
    final success = await ref.read(biometricAuthServiceProvider).authenticate();
    if (success && mounted) {
      ref.read(appLockControllerProvider.notifier).unlockWithBiometrics();
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app data?'),
        content: const Text(
          'There\'s no way to recover a forgotten PIN — it\'s never sent anywhere to verify '
          'against. Resetting requires setting up a new PIN, and your name/profile will need '
          're-entering, but your history, tasks, and folders will be restored automatically '
          'right after you do.',
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
      // Snapshot everything to a file first — SharedPreferences.clear()
      // below only empties the prefs store, so this survives the wipe and
      // lets SignupScreen hand it all back once a new PIN is set up.
      await ref.read(backupServiceProvider).saveAutoBackupBeforeReset();
      await ref.read(sharedPreferencesProvider).clear();
      ref.invalidate(historyControllerProvider);
      ref.invalidate(folderControllerProvider);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(appLockControllerProvider);
    }
  }
}
