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

  // Figma's three instances (node 706:3032) all sit at a fixed 86, so every
  // badge lines up in the right-aligned Activity column. That number is a
  // Figma-font measurement (Inter, which isn't bundled here — see
  // AppTypography.fontFamilyBody's doc comment); the OS font this actually
  // renders in is wider, so 86 is a minimum, not a hard cap: "In progress"
  // grows the pill enough to stay on one line instead of wrapping into it.
  static const double _minWidth = 86;
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
      constraints: const BoxConstraints(minWidth: _minWidth),
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
        maxLines: 1,
        style: TextStyle(
          // Figma node 706:3032 sets this label in Inter (see
          // AppTypography.fontFamilyBody's doc comment for why that isn't
          // what actually renders yet).
          fontFamily: AppTypography.fontFamilyBody,
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
