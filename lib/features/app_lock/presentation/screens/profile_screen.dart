import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ai_voice_docs/core/widgets/app_snackbar.dart';

import '../../data/avatar_store.dart';
import '../providers/app_lock_providers.dart';
import '../widgets/account_avatar.dart';

/// Avatars are downscaled on the way in — a small circular thumbnail never
/// needs a multi-thousand-pixel camera photo.
const _maxAvatarDimension = 640.0;
const _avatarQuality = 85;

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
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  DateTime? _dob;
  String? _avatarPath;
  String? _originalAvatarPath;
  bool _isSaving = false;
  bool _busyPicking = false;
  bool _initialized = false;

  // Captured up front rather than via `ref.read` inside dispose(), which
  // shouldn't touch `ref` at all — same reasoning as the diary editor's
  // speech controller.
  late final AvatarStore _avatarStore = ref.read(avatarStoreProvider);

  @override
  void dispose() {
    // A picture picked but never saved would otherwise sit on disk forever
    // with nothing referencing it — same leak `DiaryPhotoStore` callers guard
    // against. Editing this screen's other fields (name, dob, email) has no
    // such guard and is silently lost on back navigation same as before;
    // only the file needs this because only the file is otherwise permanent.
    if (_avatarPath != null && _avatarPath != _originalAvatarPath) {
      _avatarStore.delete([_avatarPath!]);
    }
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
      _avatarPath = account.avatarPath;
      _originalAvatarPath = account.avatarPath;
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
                Center(
                  child: GestureDetector(
                    onTap: _busyPicking ? null : _choosePicture,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AccountAvatar(avatarPath: _avatarPath, name: _nameController.text, radius: 48),
                        if (_busyPicking)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                              child: const Center(
                                child: SizedBox.square(
                                  dimension: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _choosePicture() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.no_accounts_outlined),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      setState(() => _avatarPath = null);
      return;
    }
    await _pickAvatar(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    setState(() => _busyPicking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxAvatarDimension,
        maxHeight: _maxAvatarDimension,
        imageQuality: _avatarQuality,
      );
      if (picked == null) return;

      final name = await _avatarStore.import(picked.path);
      // Replacing an unsaved pick from earlier in this same visit — that
      // file was never saved and nothing else can reference it, so it can
      // go immediately rather than waiting for dispose to catch it.
      if (_avatarPath != null && _avatarPath != _originalAvatarPath) {
        await _avatarStore.delete([_avatarPath!]);
      }
      if (mounted) setState(() => _avatarPath = name);
    } on PlatformException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
              ? 'Permission needed to add a photo. Allow it in your phone\'s settings.'
              : 'Could not add the photo: ${e.message ?? e.code}',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Could not add the photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyPicking = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await ref.read(appLockControllerProvider.notifier).updateProfile(
          name: _nameController.text,
          dob: _dob,
          email: _emailController.text,
          avatarPath: _avatarPath,
        );
    // The old picture (if replaced or removed) is no longer referenced by
    // anything now that the new value is saved.
    final previous = _originalAvatarPath;
    if (previous != null && previous != _avatarPath) {
      await _avatarStore.delete([previous]);
    }
    _originalAvatarPath = _avatarPath;
    if (mounted) {
      setState(() => _isSaving = false);
      AppSnackbar.show(context, 'Profile saved');
    }
  }
}
