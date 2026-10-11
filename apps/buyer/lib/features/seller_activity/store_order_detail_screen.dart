import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import 'package:shopscroll_shared/widgets/summary_row.dart';

import '../../data/models/store_order.dart';
import '../../data/providers/store_activity_providers.dart';
import '../activity/activity_logic.dart';
import '../activity/list_states.dart';
import '../checkout/checkout_logic.dart';
import '../store/seller_gate.dart';
import 'store_order_status_badge.dart';

/// The seller's order detail at `/store/activity/orders/:id` (spec 0018, AC-5).
/// Only a seller stays ([SellerGate]). Read only: the seller cannot change the
/// status (AC-17).
///
/// There is no Figma frame for it, so it copies the buyer's receipt ("order
/// receipt-user", node 3001:9058, `OrderReceiptScreen`) with these changes:
/// only this store's lines and their subtotal (no delivery fee, no total of
/// the whole order), the chosen size and color under each title, the customer's
/// name, email and phone as "Customer", and no download button or warning
/// glyph. Money shows the store currency with 3 decimals.
class StoreOrderDetailScreen extends ConsumerWidget {
  const StoreOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(storeOrderDetailProvider(orderId));

    return SellerGate(
      // Dark clock and icons on this light page. The Activity screen under it
      // asks for light ones, so this page has to say otherwise.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.white100,
          body: SafeArea(
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: detail.when(
                    loading: () => const ListLoading(),
                    error: (error, stackTrace) => ListMessage(
                      "Couldn't load this order.",
                      buttonLabel: 'Try again',
                      onPressed: () =>
                          ref.invalidate(storeOrderDetailProvider(orderId)),
                    ),
                    data: (order) => order == null
                        ? const ListMessage('Order not found')
                        : _Body(order: order),
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

class _Header extends StatelessWidget {
  const _Header();

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
              onTap: () => context.pop(),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
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
          const Text(
            'Order Details',
            style: TextStyle(
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
  const _Body({required this.order});

  final StoreOrderDetail order;

  static const TextStyle _numberStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXl,
    height: AppTypography.lineHeightXl,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _dateStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    final method = deliveryMethodOf(order.deliveryMethod);
    final place = [
      order.address,
      order.city,
      order.zip,
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    final note = order.note;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNumberLabel(order.orderNumber),
                      style: _numberStyle,
                    ),
                    Text(
                      'Purchase date : '
                      '${orderDateLabel(order.createdAt, DateTime.now())}',
                      style: _dateStyle,
                    ),
                  ],
                ),
              ),
              StoreOrderStatusBadge(status: order.status),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            spacing: AppSpacing.base,
            children: [
              for (final line in order.lines)
                _LineRow(line: line, currency: order.currency),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.xl,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.neutral300),
            ),
          ),
          child: SummaryRow(
            label: 'Subtotal',
            value: Money.format(order.subtotal, order.currency),
            emphasized: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              _Block('Customer', order.customerName ?? 'Customer', [
                ?order.customerEmail,
                ?order.customerPhone,
              ]),
              if (place.isNotEmpty)
                _Block('Delivery address', place, [
                  if (note != null && note.isNotEmpty) note,
                ]),
              if (order.deliveryMethod != null)
                _Block(
                  'Delivery method',
                  method?.orderName ?? order.deliveryMethod!,
                  const [],
                ),
              if (order.paymentMethod != null)
                _Block('Payment method', switch (order.paymentMethod) {
                  'card' => 'Paid with a credit card',
                  'cashOnDelivery' => 'Pay on delivery',
                  final other => other!,
                }, const []),
            ],
          ),
        ),
      ],
    );
  }
}

/// A line: quantity, photo, title with the chosen size and color, line total
/// (the receipt's item row, node 3001:9081, without the store header).
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.currency});

  final StoreOrderLine line;
  final String currency;

  static const double _thumb = 40;
  static const double _quantityWidth = 28;

  static const TextStyle _quantityStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static const TextStyle _detailStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
  );

  static const TextStyle _priceStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    final color = line.color;
    final size = line.size;
    final unit = Money.format(line.unitPrice, currency);
    return Semantics(
      container: true,
      label:
          '${line.quantity} times ${line.title}'
          '${size == null ? '' : ', size $size'}, '
          '${Money.format(line.total, currency)}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: _quantityWidth,
            child: Text('x${line.quantity}', style: _quantityStyle),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: _thumb,
              height: _thumb,
              child: line.imageUrl == null
                  ? const ColoredBox(color: AppColors.blackAlpha10)
                  : CachedNetworkImage(
                      imageUrl: line.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const ColoredBox(color: AppColors.blackAlpha10),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.title, style: _titleStyle),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (size != null) Text('Size $size', style: _detailStyle),
                    if (color != null)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.neutral300),
                        ),
                      ),
                    Text(unit, style: _detailStyle),
                  ],
                ),
              ],
            ),
          ),
          Text(Money.format(line.total, currency), style: _priceStyle),
        ],
      ),
    );
  }
}

/// A bold title, a bold first line and grey lines under it (the receipt's
/// block, nodes 3001:9138 to 3001:9157, drawn again here because both are
/// private to their screen).
class _Block extends StatelessWidget {
  const _Block(this.title, this.first, this.lines);

  final String title;
  final String first;
  final List<String> lines;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightLg,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral1100,
  );

  static const TextStyle _firstStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral700,
  );

  static const TextStyle _lineStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Text(title, style: _titleStyle),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(first, style: _firstStyle),
            for (final line in lines) Text(line, style: _lineStyle),
          ],
        ),
      ],
    );
  }
}
