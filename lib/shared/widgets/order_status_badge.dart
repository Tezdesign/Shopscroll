import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';

export '../../data/models/order.dart' show OrderStatus;

/// Reproduces the Figma "Order-satus" component set (node 706:3032): a
/// small pill shown on the Activity screen's order list, one of three
/// states ([OrderStatus], defined alongside the [Order] data model).

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  // Fixed width matching every real instance in Figma.
  static const double _width = 86;
  // Figma tracks this label at 0.28 letterspacing; no shared tracking
  // token exists yet, so it's kept local like elsewhere in this project.
  static const double _letterSpacing = 0.28;

  ({Color background, Color text, String label}) get _spec {
    switch (status) {
      case OrderStatus.delivered:
        return (
          background: AppColors.successAlpha10,
          text: AppColors.success400,
          label: 'Delivered',
        );
      case OrderStatus.inProgress:
        return (
          background: AppColors.warning100,
          text: AppColors.warning400,
          label: 'In progress',
        );
      case OrderStatus.canceled:
        return (
          background: AppColors.error100,
          text: AppColors.error400,
          label: 'Canceled',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;

    return Container(
      width: _width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        spec.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyDisplay,
          fontSize: AppTypography.sizeSm,
          height: AppTypography.lineHeightSm,
          fontWeight: FontWeight.w600,
          letterSpacing: _letterSpacing,
          color: spec.text,
        ),
      ),
    );
  }
}
