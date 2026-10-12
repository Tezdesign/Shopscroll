import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_policies.dart';
import '../../data/providers/store_policies_providers.dart';
import '../store/seller_gate.dart';

/// The seller's Store policies at `/store/policies`: the delivery, payment and
/// returns defaults every product inherits.
///
/// Figma node 5599:3306 (Store policies-seller). Deviations: the status bar
/// and tab bar belong to the seller shell, which has no spec yet; the "Product
/// exceptions" card is left out because products have no exception data yet;
/// the "Applied to 24 products" count is not shown for the same reason.
class StorePoliciesScreen extends ConsumerWidget {
  const StorePoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(storePoliciesProvider);
    return SellerGate(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.white100,
          body: SafeArea(
            child: Column(
              children: [
                const PolicyHeader(title: 'Store policies'),
                Expanded(
                  child: policies.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Couldn't load your store policies."),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(storePoliciesProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                    data: (p) => _Body(policies: p),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back arrow and centered title, shared by the policy screens.
class PolicyHeader extends StatelessWidget {
  const PolicyHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              onTap: () => context.pop(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/store'),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AppIcon(
                      AppIconGlyph.back,
                      color: AppColors.neutral1100,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightLg,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.policies});

  final StorePolicies policies;

  @override
  Widget build(BuildContext context) {
    final p = policies;
    final fee = Money.format(p.deliveryFee, p.currency);
    final free = p.freeDeliveryOver;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        const Text(
          'Set once. Shoppers see these on every product unless you add an '
          'exception.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightSm,
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        _PolicyCard(
          title: 'Delivery',
          headline: '${p.deliveryArea} · ${p.deliveryTime}',
          detail: free == null
              ? '$fee delivery fee'
              : '$fee delivery fee · free over ${Money.format(free, p.currency)}',
          action: 'Edit delivery',
          onEdit: () => context.push('/store/policies/delivery'),
        ),
        const SizedBox(height: AppSpacing.md),
        _PolicyCard(
          title: 'Payment',
          headline: p.paymentMethod,
          detail: p.paymentMessage,
          action: 'Edit payment',
          onEdit: () => context.push('/store/policies/payment'),
        ),
        const SizedBox(height: AppSpacing.md),
        _PolicyCard(
          title: 'Returns',
          headline: 'Returns within ${p.returnWindowDays} days',
          detail:
              '${p.returnCondition} · ${p.returnShipping} return delivery · '
              'Refund to ${p.refundMethod.toLowerCase()}',
          action: 'Edit returns',
          onEdit: () => context.push('/store/policies/returns'),
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.headline,
    required this.detail,
    required this.action,
    required this.onEdit,
  });

  final String title;
  final String headline;
  final String detail;
  final String action;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral1100,
                  ),
                ),
              ),
              const Text(
                'Store default',
                style: TextStyle(
                  fontSize: AppTypography.sizeXs,
                  color: AppColors.primary400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            headline,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeSm,
              height: AppTypography.lineHeightSm,
              color: AppColors.neutral1100,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            style: const TextStyle(
              fontSize: AppTypography.sizeXs,
              height: AppTypography.lineHeightXs,
              color: AppColors.neutral700,
            ),
          ),
          Semantics(
            button: true,
            label: action,
            excludeSemantics: true,
            onTap: onEdit,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Text(
                  action,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
