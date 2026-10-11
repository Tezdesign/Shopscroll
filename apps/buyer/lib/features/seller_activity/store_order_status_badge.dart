import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../../data/models/store_order.dart';
import '../../shared/widgets/order_status_badge.dart';

/// The status pill of a store order (Figma "Order-satus", node 706:3032). The
/// three statuses the buyer also has reuse [OrderStatusBadge]. Returned is a
/// fourth style that Figma does not draw (spec 0018): the same pill in the
/// neutral tokens, so it reads as "closed" and not as good or bad news.
class StoreOrderStatusBadge extends StatelessWidget {
  const StoreOrderStatusBadge({super.key, required this.status});

  final StoreOrderStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StoreOrderStatus.delivered:
        return const OrderStatusBadge(status: OrderStatus.delivered);
      case StoreOrderStatus.inProgress:
        return const OrderStatusBadge(status: OrderStatus.inProgress);
      case StoreOrderStatus.canceled:
        return const OrderStatusBadge(status: OrderStatus.canceled);
      case StoreOrderStatus.returned:
        return Container(
          constraints: const BoxConstraints(minWidth: 86),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Text(
            'Returned',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeSm,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.28,
              color: AppColors.neutral800,
            ),
          ),
        );
    }
  }
}
