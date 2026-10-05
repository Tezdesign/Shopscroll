import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/coming_soon_screen.dart';

import '../../core/area/app_area.dart';
import '../../core/onboarding/onboarding_prefs.dart';
import '../../data/providers/user_profile_providers.dart';
import 'area_toggle.dart';

/// The store area at `/store` (spec 0014, AC-5): a placeholder with the
/// [AreaToggle] on top. No seller features are built here, they get their own
/// scope rows and specs.
///
/// Only a seller stays. While the profile loads it shows a spinner, and for a
/// visitor, a buyer, or a profile that cannot be read it goes to the buyer
/// area instead (AC-3, for example when the role was removed while this area
/// was remembered). A buyer's memory is cleared so the next launch opens the
/// buyer area directly; a failed read keeps it, because that says nothing
/// about the role.
class StoreAreaScreen extends ConsumerWidget {
  const StoreAreaScreen({super.key});

  void _leave(BuildContext context, WidgetRef ref, {required bool forget}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (forget) ref.read(onboardingPrefsProvider).setLastArea('buyer');
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(signedInUserIdProvider);
    if (id == null) {
      _leave(context, ref, forget: true);
      return const _Loading();
    }

    return ref
        .watch(userProfileByIdProvider(id))
        .when(
          loading: () => const _Loading(),
          error: (error, stackTrace) {
            _leave(context, ref, forget: false);
            return const _Loading();
          },
          data: (profile) {
            if (profile?.role != UserRole.seller) {
              _leave(context, ref, forget: true);
              return const _Loading();
            }
            return const Scaffold(
              backgroundColor: AppColors.neutral100,
              body: SafeArea(
                child: Column(
                  children: [
                    AreaToggle(current: AppArea.store),
                    Expanded(
                      child: ComingSoonScreen(
                        label: 'Your store',
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.neutral100,
    body: Center(child: CircularProgressIndicator()),
  );
}
