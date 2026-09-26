import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/providers/core_providers.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';
import 'package:ai_voice_docs/core/widgets/paper_background.dart';
import 'package:ai_voice_docs/features/diary/presentation/providers/diary_providers.dart';
import 'package:ai_voice_docs/features/folders/presentation/providers/folder_providers.dart';
import 'package:ai_voice_docs/features/history/presentation/providers/history_providers.dart';
import 'package:ai_voice_docs/features/settings/presentation/providers/settings_providers.dart';
import 'package:ai_voice_docs/features/tasks/presentation/providers/task_providers.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Prompts for fingerprint/face if the user turned it on and the phone can
  /// do it; on success unlocks without the PIN. Silent no-op otherwise, and a
  /// cancelled/failed prompt just leaves the PIN field to use.
  Future<void> _tryBiometric() async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!settings.biometricUnlock || !mounted) return;
    final service = ref.read(biometricServiceProvider);
    if (!await service.isAvailable() || !mounted) return;
    final ok = await service.authenticate('Unlock Voice Docs AI');
    if (ok && mounted) {
      ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider).value;
    final name = lockState?.account?.name ?? '';
    final biometricEnabled =
        (ref.watch(settingsControllerProvider).value?.biometricUnlock ?? false) &&
        (ref.watch(biometricAvailableProvider).value ?? false);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(appLockControllerProvider, (previous, next) {
      final error = next.value?.errorMessage;
      if (error != null && error != previous?.value?.errorMessage) {
        AppSnackbar.show(context, error, isError: true);
        setState(() => _pinController.clear());
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          PaperBackground(child: const SizedBox.expand()),
          // Purely decorative atmosphere behind the PIN pad — tinted with
          // whatever palette/theme the user picked rather than a fixed image,
          // so it stays correct across every theme instead of just Midnight.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [scheme.primary.withValues(alpha: 0.18), scheme.primary.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 56, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your PIN to continue',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    _PinDots(length: _pinController.text.length, scheme: scheme),
                    const SizedBox(height: 32),
                    _Keypad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onBiometric: biometricEnabled ? _tryBiometric : null,
                    ),
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
        ],
      ),
    );
  }

  void _onDigit(String digit) {
    if (_pinController.text.length >= 4) return;
    setState(() => _pinController.text += digit);
    if (_pinController.text.length == 4) _submit();
  }

  void _onBackspace() {
    if (_pinController.text.isEmpty) return;
    setState(() => _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1));
  }

  void _submit() {
    if (_pinController.text.length != 4) return;
    ref.read(appLockControllerProvider.notifier).unlock(_pinController.text);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app data?'),
        content: const Text(
          'There\'s no way to recover a forgotten PIN — it\'s never sent anywhere to verify '
          'against. Resetting deletes ALL saved history, folders, and settings from this '
          'device, then lets you set up a new PIN. This cannot be undone.',
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
      await ref.read(sharedPreferencesProvider).clear();
      await ref.read(diaryPhotoStoreProvider).clearAll();
      await ref.read(avatarStoreProvider).clearAll();
      await ref.read(appBackgroundPhotoStoreProvider).clearAll();
      ref.invalidate(historyControllerProvider);
      ref.invalidate(folderControllerProvider);
      ref.invalidate(taskControllerProvider);
      ref.invalidate(diaryControllerProvider);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(appLockControllerProvider);
    }
  }
}

/// Four circles showing how many digits have been entered so far — filled
/// for each entered digit, outlined for the rest. Never shows the digits
/// themselves, same privacy the old obscured text field had.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.scheme});

  final int length;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? scheme.primary : Colors.transparent,
              border: Border.all(color: scheme.primary, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// A 3x4 numeric keypad — digits 1-9, then a bottom row of
/// [biometric-or-blank, 0, backspace]. Replaces the OS keyboard entirely so
/// the PIN screen looks and behaves like a lock screen, not a form.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace, required this.onBiometric});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final digit in row) _KeypadKey(label: digit, onTap: () => onDigit(digit))],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              onBiometric == null
                  ? const SizedBox(width: 64, height: 64)
                  : _KeypadKey(icon: Icons.fingerprint_rounded, onTap: onBiometric!),
              _KeypadKey(label: '0', onTap: () => onDigit('0')),
              _KeypadKey(icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({this.label, this.icon, required this.onTap}) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  )
                : Icon(icon, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
