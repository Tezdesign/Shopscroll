import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../../core/area/app_area.dart';
import '../../core/onboarding/onboarding_prefs.dart';
import '../../shared/widgets/area_switch.dart';

/// The Buyer | Seller switch an approved seller uses to change area (spec 0014,
/// AC-4), drawn as in the seller Profile of the Figma file (see [AreaSwitch]).
/// It lives in the Profile tab's header, where it replaces the Become a seller
/// button (`ProfileAreaAction`), and at the top of the store area. Tapping the
/// other half opens that area at once and remembers it for the next launch
/// (AC-3). A buyer never sees it, and no other buyer screen shows it.
class AreaToggle extends ConsumerWidget {
  const AreaToggle({
    super.key,
    required this.current,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.base,
      vertical: AppSpacing.sm,
    ),
  });

  final AppArea current;

  /// Space around the pill. The Profile tab passes [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: padding,
      child: AreaSwitch(
        sellerSelected: current == AppArea.store,
        onChanged: (seller) {
          final target = seller ? AppArea.store : AppArea.buyer;
          if (target == current) return;
          ref.read(onboardingPrefsProvider).setLastArea(target.name);
          context.go(target == AppArea.store ? '/store' : '/');
        },
      ),
    );
  }
}
