import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../data/providers/order_providers.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/order_status_badge.dart';
import 'activity_logic.dart';
import 'list_states.dart';

/// The Purchases tab (spec 0008, AC-3, AC-4): one block per order, newest
/// first, from [ordersProvider]. Tapping a block opens the order details
/// coming soon page.
class PurchasesTab extends ConsumerWidget {
  const PurchasesTab({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(ordersProvider)
        .when(
          loading: () => const ListLoading(),
          error: (error, stackTrace) => ListMessage(
            "Couldn't load purchases.",
            buttonLabel: 'Try again',
            onPressed: () => ref.invalidate(ordersProvider),
          ),
          data: (orders) {
            if (orders.isEmpty) return const ListMessage('No purchases yet');
            final shown = filterOrders(newestOrdersFirst(orders), query);
            if (shown.isEmpty) return ListMessage.noResults(query);
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: shown.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.base),
              itemBuilder: (context, index) =>
                  _PurchaseBlock(order: shown[index]),
            );
          },
        );
  }
}

/// Figma node 322:2641: the date with a chevron, the first two thumbnails
/// (80 by 80) and "+ N products", then the total and the status badge.
class _PurchaseBlock extends StatelessWidget {
  const _PurchaseBlock({required this.order});

  final Order order;

  static const double _thumb = 80;

  static const TextStyle _dateStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _extraStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    final date = orderDateLabel(order.createdAt, DateTime.now());
    final extra = extraProductsLabel(order);
    final total = orderTotalLabel(order);

    return Semantics(
      button: true,
      label: 'Order from $date, $total, ${_statusWord(order.status)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/activity/orders/${order.id}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(date, style: _dateStyle),
                  const AppIcon(
                    AppIconGlyph.forward,
                    color: AppColors.neutral1100,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final item in order.items.take(2)) ...[
                    _Thumbnail(url: item.product.imageUrl, size: _thumb),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (extra != null) Text(extra, style: _extraStyle),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(total, style: _dateStyle),
                  OrderStatusBadge(status: order.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusWord(OrderStatus status) => switch (status) {
    OrderStatus.delivered => 'Delivered',
    OrderStatus.inProgress => 'In progress',
    OrderStatus.canceled => 'Canceled',
  };
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? const ColoredBox(color: AppColors.blackAlpha10)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: AppColors.blackAlpha10),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: AppColors.blackAlpha10),
              ),
      ),
    );
  }
}
