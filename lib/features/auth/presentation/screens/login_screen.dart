import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';

/// Phone number + WhatsApp OTP sign-in, replacing the old email/password
/// flow entirely. Two steps in one screen (rather than two routes) so
/// "change number" is just a state flip, not a navigation stack push.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  String _submittedPhoneNumber = '';
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        AppSnackbar.show(context, next.errorMessage!, isError: true);
      }
    });

    final formState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mic_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _codeSent
                        ? 'Enter the code sent to $_submittedPhoneNumber on WhatsApp'
                        : 'Sign in with your WhatsApp number',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  if (!_codeSent) ..._phoneStep(formState) else ..._codeStep(formState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(AuthFormState formState) {
    return [
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(
          labelText: 'WhatsApp number',
          hintText: '+14155551234',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: (value) => (value == null || !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value))
            ? 'Enter your number in international format, e.g. +14155551234'
            : null,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: formState.isSubmitting ? null : _sendCode,
        child: formState.isSubmitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Send code via WhatsApp'),
      ),
    ];
  }

  List<Widget> _codeStep(AuthFormState formState) {
    return [
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        style: Theme.of(context).textTheme.headlineSmall,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: '6-digit code',
          counterText: '',
        ),
        validator: (value) => (value == null || value.length != 6) ? 'Enter the 6-digit code' : null,
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: formState.isSubmitting ? null : _verifyCode,
        child: formState.isSubmitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Verify'),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: formState.isSubmitting ? null : () => setState(() => _codeSent = false),
            child: const Text('Change number'),
          ),
          TextButton(
            onPressed: (formState.isSubmitting || _resendCooldown > 0) ? null : _sendCode,
            child: Text(_resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend code'),
          ),
        ],
      ),
    ];
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phoneNumber = _phoneController.text.trim();
    final sent = await ref.read(authControllerProvider.notifier).sendOtp(phoneNumber);
    if (sent && mounted) {
      setState(() {
        _codeSent = true;
        _submittedPhoneNumber = phoneNumber;
      });
      _startResendCooldown();
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown -= 1);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).verifyOtp(
          phoneNumber: _submittedPhoneNumber,
          code: _codeController.text.trim(),
        );
    // On success, authStateChangesProvider emits the signed-in user and the
    // router's redirect callback moves off this screen automatically.
  }
}
