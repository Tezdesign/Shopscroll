import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../../core/area/app_area.dart';
import '../../core/onboarding/onboarding_prefs.dart';
import '../../data/providers/user_profile_providers.dart';

/// Shows [child] only to a signed in seller, and sends everyone else to the
/// buyer area (spec 0014, AC-3 and AC-5; spec 0015, AC-1). It is the rule the
/// store area always had, kept in one place for every store area screen.
///
/// While the profile loads it shows a spinner. A visitor, a buyer, or a
/// profile that cannot be read goes to the buyer area (for example when the
/// role was removed while this area was remembered). A buyer's memory of the
/// area is cleared so the next launch opens the buyer area directly; a failed
/// read keeps it, because that says nothing about the role.
class SellerGate extends ConsumerWidget {
  const SellerGate({super.key, required this.child});

  final Widget child;

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
            return child;
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
