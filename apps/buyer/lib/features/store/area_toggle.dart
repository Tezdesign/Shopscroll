import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../../core/area/app_area.dart';
import '../../core/onboarding/onboarding_prefs.dart';
import '../../shared/widgets/account_type_toggle.dart';

/// The Buyer | Store owner switch an approved seller sees at the top of the
/// buyer area's tab screens and of the store area (spec 0014, AC-4). It reuses
/// the Log in screen's "Who are you" pill. Tapping the other half opens that
/// area at once and remembers it for the next launch (AC-3). A buyer never
/// sees it, and pushed detail screens (a product, the cart) do not show it:
/// `AppShell` decides where it appears.
class AreaToggle extends ConsumerWidget {
  const AreaToggle({super.key, required this.current});

  final AppArea current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: AccountTypeToggle(
        selected: current == AppArea.store
            ? AccountType.storeOwner
            : AccountType.buyer,
        onChanged: (type) {
          final target = type == AccountType.storeOwner
              ? AppArea.store
              : AppArea.buyer;
          if (target == current) return;
          ref.read(onboardingPrefsProvider).setLastArea(target.name);
          context.go(target == AppArea.store ? '/store' : '/');
        },
      ),
    );
  }
}
