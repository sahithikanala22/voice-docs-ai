import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../providers/app_lock_providers.dart';

/// Lets the user view/edit the profile info collected beyond the signup
/// name+PIN — date of birth and email. Both stay purely local, same as the
/// rest of the account record; nothing here is verified or sent anywhere.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  DateTime? _dob;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(appLockControllerProvider).value?.account;

    if (!_initialized && account != null) {
      _initialized = true;
      _nameController = TextEditingController(text: account.name);
      _emailController = TextEditingController(text: account.email ?? '');
      _dob = account.dob;
    }
    if (!_initialized) {
      // Account hasn't loaded yet (shouldn't normally happen, since this
      // screen is only reachable once already unlocked) — avoid a crash.
      _nameController = TextEditingController();
      _emailController = TextEditingController();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(
                      _dob == null ? 'Not set' : DateFormat('MMM d, yyyy').format(_dob!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return value.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await ref.read(appLockControllerProvider.notifier).updateProfile(
          name: _nameController.text,
          dob: _dob,
          email: _emailController.text,
        );
    if (mounted) {
      setState(() => _isSaving = false);
      AppSnackbar.show(context, 'Profile saved');
    }
  }
}
