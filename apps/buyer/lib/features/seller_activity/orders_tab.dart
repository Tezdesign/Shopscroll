import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_order.dart';
import '../../data/providers/store_activity_providers.dart';
import 'activity_message.dart';
import 'store_order_status_badge.dart';

const _tapSize = 44.0;

/// The label of a status chip (Figma "Order-satus-category").
const _chips = [
  (status: StoreOrderStatus.delivered, label: 'Delivered'),
  (status: StoreOrderStatus.inProgress, label: 'In progress'),
  (status: StoreOrderStatus.canceled, label: 'Canceled'),
];

/// The Orders tab of the seller's Activity area (spec 0018, AC-2 to AC-4,
/// AC-14): three status chips, then one row per store order, newest first,
/// loading 20 at a time, with pull to refresh.
///
/// Figma node 3001:11659. Deviations: money shows the store currency with 3
/// decimals (`450.000 TND`) where the frame draws `$450`; the active chip is
/// filled black (the frame draws only the idle chip); a chip is [AppRadius.md]
/// where the frame uses 10. A row opens the order detail.
class OrdersTab extends ConsumerWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(storeOrderStatusFilterProvider);
    final search = ref.watch(storeActivitySearchProvider);
    final orders = ref.watch(storeOrdersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final chip in _chips) ...[
                  _StatusChip(
                    label: chip.label,
                    active: active == chip.status,
                    // Tapping the active chip clears it (AC-3).
                    onTap: () =>
                        ref
                            .read(storeOrderStatusFilterProvider.notifier)
                            .state = active == chip.status
                        ? null
                        : chip.status,
                  ),
                  if (chip != _chips.last)
                    const SizedBox(width: AppSpacing.base),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => ActivityMessage(
              text: "Couldn't load your orders.",
              onRetry: () => ref.invalidate(storeOrdersProvider),
            ),
            data: (state) {
              if (state.orders.isEmpty) {
                return ActivityMessage(
                  text: search.isEmpty
                      ? 'No orders yet'
                      : 'No results found for “$search”',
                  // Pulling still refreshes an empty list.
                  onRefresh: () => ref.refresh(storeOrdersProvider.future),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(storeOrdersProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    0,
                    AppSpacing.base,
                    // Clears the "+" button.
                    96,
                  ),
                  itemCount: state.orders.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.base),
                  itemBuilder: (context, index) {
                    if (index < state.orders.length) {
                      return _OrderRow(order: state.orders[index]);
                    }
                    return _ListFooter(state: state);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.neutral100 : AppColors.neutral1100;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _tapSize),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.neutral1100 : AppColors.neutral100,
            border: Border.all(color: AppColors.neutral1100),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIconGlyph.deals, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeSm,
                  height: AppTypography.lineHeightSm,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final StoreOrder order;

  static const _small = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
  );
  static const _large = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    final number = order.orderNumber.toString().padLeft(6, '0');
    final name = order.customerName ?? 'Customer';
    final total = 'Total : ${Money.format(order.total, order.currency)}';

    return Semantics(
      button: true,
      label:
          'Order $number, $name'
          '${order.place.isEmpty ? '' : ', ${order.place}'}, $total',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order#$number',
                    style: _small.copyWith(color: AppColors.neutral600),
                  ),
                  Text(name, style: _large),
                  if (order.place.isNotEmpty)
                    Row(
                      children: [
                        const AppIcon(AppIconGlyph.location),
                        const SizedBox(width: AppSpacing.xs / 2),
                        Expanded(
                          child: Text(
                            order.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _small.copyWith(
                              color: AppColors.neutral1100,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Text(total, style: _large),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StoreOrderStatusBadge(status: order.status),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) =>
      context.push('/store/activity/orders/${order.orderId}');
}

/// The end of the list: a spinner while the next page loads, or a retry when
/// that load failed.
class _ListFooter extends ConsumerWidget {
  const _ListFooter({required this.state});

  final StoreOrdersState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreFailed) {
      return Center(
        child: RetryButton(
          onPressed: () => ref.read(storeOrdersProvider.notifier).loadMore(),
        ),
      );
    }
    // The next page starts as soon as this row is built (it is built only when
    // the list has scrolled near its end).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(storeOrdersProvider.notifier).loadMore(),
    );
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.base),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
