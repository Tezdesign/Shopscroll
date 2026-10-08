import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../core/area/app_area.dart';
import '../store/area_toggle.dart';

/// The top right action of the Profile header (Figma node 322:2872). A buyer
/// sees "Become a seller", which opens the Seller application screen. Once an
/// application is accepted and the person is a seller, it becomes the Buyer |
/// Store owner switch, so the Profile tab is where a seller changes area
/// (spec 0014, AC-4). `AppShell` hides its own top switch on this tab so the
/// two never show together.
class ProfileAreaAction extends ConsumerWidget {
  const ProfileAreaAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isSellerProvider)) {
      return const AreaToggle(
        current: AppArea.buyer,
        padding: EdgeInsets.zero,
      );
    }
    return AppButton(
      label: 'Become a seller',
      size: AppButtonSize.small,
      onPressed: () => context.push('/profile/seller-application'),
    );
  }
}
