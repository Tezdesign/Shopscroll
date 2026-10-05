import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../core/area/app_area.dart';
import 'area_toggle.dart';
import 'seller_gate.dart';

/// The store area at `/store` (spec 0014, AC-5) with the [AreaToggle] on top.
/// Only a seller stays ([SellerGate]).
///
/// Until the seller shell (header, tab bar, Home, Activity, Profile) has its
/// own spec, this holds two entry buttons for the product features of spec
/// 0015: the Products list and Add product. They move into the shell later.
class StoreAreaScreen extends StatelessWidget {
  const StoreAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerGate(
      child: Scaffold(
        backgroundColor: AppColors.neutral100,
        body: SafeArea(
          child: Column(
            children: [
              const AreaToggle(current: AppArea.store),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your store',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: AppTypography.sizeXl,
                          height: AppTypography.lineHeightXl,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral1100,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      AppButton(
                        label: 'Add product',
                        leadingIcon: Icons.add,
                        onPressed: () => context.push('/store/products/new'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Products',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.push('/store/products'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
