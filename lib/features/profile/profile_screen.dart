import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../../shared/widgets/settings_row.dart';

/// The real, signed in Profile tab (spec 0005), reproducing Figma node
/// 322:2872. Only ever built by [ClerkAuthBuilder]'s `signedInBuilder` in
/// `app_router.dart`, so [authState] always has a real `user`.
///
/// Sign out and delete account (previously the unlinked, now retired
/// `AccountScreen` from spec 0004) live here as the Log out / Delete
/// account rows. Every row for a feature this app doesn't have yet (become
/// a seller, delivery addresses, payments, the legal pages, and so on)
/// opens the same [ComingSoonScreen] already used for the Activity tab,
/// labeled for that row, rather than doing nothing when tapped.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.authState});

  final ClerkAuthState authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = authState.user!.id;
    final profileAsync = ref.watch(userProfileByIdProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => _ProfileContent(
            authState: authState,
            profile: profile,
          ),
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
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.authState, required this.profile});

  final ClerkAuthState authState;

  /// Null only in the brief window between a fresh sign in and spec 0004's
  /// own upsert finishing; falls back to Clerk's own user fields so the
  /// page still renders something real rather than a blank screen.
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final user = authState.user!;
    final name = profile?.name ??
        (user.hasName ? user.name : (user.username ?? 'Shopper'));
    final avatarUrl = profile?.avatarUrl ?? user.imageUrl;
    final followingCount = profile?.followingCount ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      children: [
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary100,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: 40, color: AppColors.primary400)
                  : null,
            ),
            const Spacer(),
            AppButton(
              label: 'Become a seller',
              size: AppButtonSize.small,
              onPressed: () => _openComingSoon(
                context,
                'Become a seller',
                Icons.storefront_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$followingCount Stores following',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Edit profile',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              leadingIcon: Icons.edit_outlined,
              onPressed: () => context.push('/profile/edit'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SettingsSection(
          title: 'Generals',
          rows: [
            SettingsRow(
              label: 'Shopping in',
              onTap: () => _openComingSoon(
                context,
                'Shopping in',
                Icons.flag_outlined,
              ),
            ),
            SettingsRow(
              label: 'Language',
              onTap: () => _openComingSoon(
                context,
                'Language',
                Icons.language,
              ),
            ),
            SettingsRow(
              label: 'Delivery addresses',
              onTap: () => _openComingSoon(
                context,
                'Delivery addresses',
                Icons.location_on_outlined,
              ),
            ),
            SettingsRow(
              label: 'Payments',
              onTap: () => _openComingSoon(
                context,
                'Payments',
                Icons.payment_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingsSection(
          title: 'Help and Legal',
          rows: [
            SettingsRow(
              label: 'Contact us',
              onTap: () => _openComingSoon(
                context,
                'Contact us',
                Icons.chat_bubble_outline,
              ),
            ),
            SettingsRow(
              label: 'My reports',
              onTap: () => _openComingSoon(
                context,
                'My reports',
                Icons.warning_amber_rounded,
              ),
            ),
            SettingsRow(
              label: 'Privacy policy',
              trailingIcon: AppIconGlyph.openExternal,
              onTap: () => _openComingSoon(
                context,
                'Privacy policy',
                Icons.privacy_tip_outlined,
              ),
            ),
            SettingsRow(
              label: 'Terms and conditions',
              trailingIcon: AppIconGlyph.openExternal,
              onTap: () => _openComingSoon(
                context,
                'Terms and conditions',
                Icons.description_outlined,
              ),
            ),
            SettingsRow(
              label: 'FAQ',
              trailingIcon: AppIconGlyph.openExternal,
              onTap: () => _openComingSoon(
                context,
                'FAQ',
                Icons.help_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsRow(
          label: 'Log out',
          trailingIcon: AppIconGlyph.logout,
          labelColor: AppColors.error400,
          onTap: authState.signOut,
        ),
        SettingsRow(
          label: 'Delete account',
          trailingIcon: AppIconGlyph.delete,
          labelColor: AppColors.error400,
          onTap: () => _confirmDeleteAccount(context, authState),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  void _openComingSoon(BuildContext context, String label, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComingSoonScreen(label: label, icon: icon),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    ClerkAuthState authState,
  ) async {
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.rows});

  final String title;
  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        ...rows,
      ],
    );
  }
}
