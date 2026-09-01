import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

/// Opened from the Profile screen's Edit profile button (spec 0005, AC-5,
/// AC-6). Only name, username, and bio are editable; the profile photo is
/// out of scope for this pass (see spec 0005's Follow up). Reads the
/// signed in person's id straight off [ClerkAuth], since this route is
/// only ever reachable from the signed in [ProfileScreen].
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _usernameError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ClerkAuth.of(context, listen: false).user!.id;
    final profileAsync = ref.watch(userProfileByIdProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        title: Text('Edit profile', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (!_initialized) {
              _nameController.text = profile?.name ?? '';
              _usernameController.text = profile?.username ?? '';
              _bioController.text = profile?.bio ?? '';
              _initialized = true;
            }
            return _buildForm(context, userId);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Could not load your profile.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, String userId) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          Text('Name', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _nameController,
            hintText: 'Enter your name',
            validator: (value) => (value == null || value.trim().isEmpty)
                ? "Name can't be empty"
                : null,
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Username', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _usernameController,
            hintText: 'Enter your username',
            errorText: _usernameError,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? "Username can't be empty"
                : null,
            onChanged: (_) {
              if (_usernameError != null) setState(() => _usernameError = null);
            },
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Bio', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _bioController,
            hintText: 'Tell people about yourself',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _saving ? 'Saving...' : 'Save',
            enabled: !_saving,
            onPressed: () => _save(userId),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _usernameError = null;
    });

    try {
      await ref.read(userProfileRepositoryProvider).updateUserProfile(
            userId,
            name: _nameController.text.trim(),
            username: _usernameController.text.trim(),
            bio: _bioController.text.trim(),
          );
      ref.invalidate(userProfileByIdProvider(userId));
      if (mounted) Navigator.of(context).pop();
    } on UsernameTakenException {
      setState(() => _usernameError = 'This username is taken');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
