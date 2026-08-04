import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The signed in `/profile` tab (spec 0004, Build plan task 7): sign out
/// and delete account are the only two actions this feature's scope calls
/// for — a fuller profile/settings surface is a later feature's job.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.authState});

  final ClerkAuthState authState;

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    final name = user?.hasName == true ? user!.name : (user?.username ?? '');
    final email = user?.email;

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        title: Text('Account', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary100,
              backgroundImage:
                  user?.imageUrl != null ? NetworkImage(user!.imageUrl!) : null,
              child: user?.imageUrl == null
                  ? Icon(Icons.person, size: 36, color: AppColors.primary400)
                  : null,
            ),
            const SizedBox(height: AppSpacing.base),
            if (name.isNotEmpty)
              Text(name, style: AppTypography.titleLarge),
            if (email != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                email,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral700,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => authState.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: AppSpacing.base),
            TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context),
              icon: Icon(Icons.delete_outline, color: AppColors.error400),
              label: Text(
                'Delete account',
                style: TextStyle(color: AppColors.error400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your cart, likes, and saves. Your past orders are '
          'kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error400)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await authState.deleteUser();
    }
  }
}
