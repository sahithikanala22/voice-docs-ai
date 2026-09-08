import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../providers/app_lock_providers.dart';

/// Auto-inserts the `/` separators as digits are typed, building up a
/// DD/MM/YYYY string without the user having to type them.
class _DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

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
  late final TextEditingController _dobController;
  String? _avatarPath;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(appLockControllerProvider).value?.account;

    if (!_initialized && account != null) {
      _initialized = true;
      _nameController = TextEditingController(text: account.name);
      _emailController = TextEditingController(text: account.email ?? '');
      _dobController = TextEditingController(
        text: account.dob == null
            ? ''
            : DateFormat('dd/MM/yyyy').format(account.dob!),
      );
      _avatarPath = account.avatarPath;
    }
    if (!_initialized) {
      // Account hasn't loaded yet (shouldn't normally happen, since this
      // screen is only reachable once already unlocked) — avoid a crash.
      _nameController = TextEditingController();
      _emailController = TextEditingController();
      _dobController = TextEditingController();
    }

    // A path can outlive its file — e.g. restored from a backup that didn't
    // carry the image bytes with it — so check existence rather than
    // trusting the path and risking FileImage throwing on a missing file.
    final avatarFile = _avatarPath == null ? null : File(_avatarPath!);
    final hasAvatar = avatarFile?.existsSync() ?? false;

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
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: hasAvatar
                            ? FileImage(avatarFile!)
                            : null,
                        child: !hasAvatar
                            ? Icon(
                                Icons.person_rounded,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _changeAvatar,
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_DobInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'DD/MM/YYYY',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return _parseDob(value.trim()) == null
                        ? 'Enter a valid date as DD/MM/YYYY'
                        : null;
                  },
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
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      await _deleteStoredAvatarFile();
      await ref.read(appLockControllerProvider.notifier).updateAvatar(null);
      if (mounted) setState(() => _avatarPath = null);
      return;
    }

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Could not open ${choice == 'camera' ? 'the camera' : 'the gallery'}.',
          isError: true,
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    final savedPath = await _saveAvatarFile(picked);
    await ref.read(appLockControllerProvider.notifier).updateAvatar(savedPath);
    if (mounted) setState(() => _avatarPath = savedPath);
  }

  /// Copies the picked image into the app's own documents directory under a
  /// fixed filename, overwriting any previous picture — so the profile
  /// picture keeps working even if the original gallery file is later moved
  /// or deleted, and old copies never pile up on disk.
  Future<String> _saveAvatarFile(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/profile_avatar.jpg';
    final destFile = File(destPath);
    if (await destFile.exists()) await destFile.delete();
    await File(picked.path).copy(destPath);
    return destPath;
  }

  Future<void> _deleteStoredAvatarFile() async {
    final path = _avatarPath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Parses a `DD/MM/YYYY` string into a [DateTime], rejecting anything
  /// that isn't a real calendar date or falls outside a plausible birth
  /// date range (not in the future, not more than 120 years ago).
  DateTime? _parseDob(String text) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > DateUtils.getDaysInMonth(year, month)) return null;

    final date = DateTime(year, month, day);
    final now = DateTime.now();
    if (date.isAfter(now) || date.isBefore(DateTime(now.year - 120))) {
      return null;
    }
    return date;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final dobText = _dobController.text.trim();
    await ref
        .read(appLockControllerProvider.notifier)
        .updateProfile(
          name: _nameController.text,
          dob: dobText.isEmpty ? null : _parseDob(dobText),
          email: _emailController.text,
        );
    if (mounted) {
      setState(() => _isSaving = false);
      AppSnackbar.show(context, 'Profile saved');
    }
  }
}
