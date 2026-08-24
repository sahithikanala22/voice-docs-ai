import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/widgets/floating_dots_background.dart';

import '../providers/app_lock_providers.dart';

/// First-launch screen: pick a name and a 4-digit PIN. Purely local — there
/// is no account recovery beyond the "forgot PIN" reset on the lock screen,
/// since nothing here is verified against a server.
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
      body: FloatingDotsBackground(
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
                      'Your name and PIN stay on this device only — there\'s no account '
                      'recovery beyond resetting the app\'s data if you forget your PIN.',
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
    // On success, the router's redirect callback moves off this screen
    // automatically once appLockControllerProvider reports isUnlocked.
    if (mounted) setState(() => _isSubmitting = false);
  }
}
