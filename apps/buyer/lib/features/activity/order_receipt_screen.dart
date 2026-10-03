import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/order.dart';
import '../../data/providers/order_providers.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import '../../shared/widgets/order_status_badge.dart';
import 'package:shopscroll_shared/widgets/summary_row.dart';
import '../checkout/checkout_logic.dart';
import 'activity_logic.dart';
import 'list_states.dart';

/// Reproduces the Figma "order receipt-user" screen (node 3001:9058): opened
/// at `/activity/orders/:id` when a buyer taps an order in the Purchases tab
/// (`PurchasesTab._PurchaseBlock`). Shows the order number, purchase date and
/// status, every line item, the price breakdown, and the payment, shipping,
/// delivery and contact details the order was placed with.
///
/// Deviations from the frame: the top right warning glyph and the bottom
/// "Download order receipt" button are drawn as in the design but do
/// nothing — a PDF export needs its own spec, same reasoning as
/// `address_sheet.dart`'s "Add current location". No device status bar or
/// bottom tab bar, both belong to the shell around this route.
class OrderReceiptScreen extends ConsumerWidget {
  const OrderReceiptScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: order.when(
                loading: () => const ListLoading(),
                error: (error, stackTrace) => ListMessage(
                  "Couldn't load this order.",
                  buttonLabel: 'Try again',
                  onPressed: () => ref.invalidate(orderByIdProvider(orderId)),
                ),
                data: (order) =>
                    order == null
                        ? const ListMessage('Order not found')
                        : _Body(order: order),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma node 3001:9069: a back chevron, the centred title, and a decorative
/// warning glyph (see the screen's deviation note above).
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
            'Order Receipt',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightLg,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.base),
              child: Semantics(
                button: true,
                enabled: false,
                label: 'Report an issue',
                excludeSemantics: true,
                child: const AppIcon(
                  AppIconGlyph.report,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});

  final Order order;

  static const TextStyle _orderNumberStyle = TextStyle(
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

  static const TextStyle _paymentTitleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _paymentStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    final fee = order.deliveryFee ?? 0;
    final subtotal = order.subtotal ?? order.totalAmount - fee;
    final address = order.shippingAddress;
    final method = deliveryMethodOf(order.deliveryMethod);
    final arrival = order.estimatedDelivery;
    final contact = order.contact;
    final byCard = order.paymentMethod == 'card';

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
                      style: _orderNumberStyle,
                    ),
                    Text(
                      'Purchase date : '
                      '${orderDateLabel(order.createdAt, DateTime.now())}',
                      style: _dateStyle,
                    ),
                  ],
                ),
              ),
              OrderStatusBadge(status: order.status),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            spacing: AppSpacing.base,
            children: [for (final item in order.items) _ItemRow(item: item)],
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
          child: Column(
            spacing: AppSpacing.sm,
            children: [
              SummaryRow(label: 'Order subtotal', value: moneyLabel(subtotal)),
              SummaryRow(label: 'Delivery', value: moneyLabel(fee)),
              SummaryRow(
                label: 'Total price',
                value: moneyLabel(order.totalAmount),
                emphasized: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              if (order.paymentMethod != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    const Text('Payment Method', style: _paymentTitleStyle),
                    Row(
                      spacing: AppSpacing.xs,
                      children: [
                        Icon(
                          byCard
                              ? Icons.credit_card_outlined
                              : Icons.payments_outlined,
                          size: 24,
                          color: AppColors.neutral1100,
                        ),
                        Text(switch (order.paymentMethod) {
                          'card' => 'Paid with a credit card',
                          'cashOnDelivery' => 'Pay on delivery',
                          final other => other!,
                        }, style: _paymentStyle),
                      ],
                    ),
                  ],
                ),
              if (address != null)
                _Block('Shipping Address', address.country, [
                  '${address.address}, ${address.city}, ${address.zip}',
                  if (address.note.isNotEmpty) address.note,
                ]),
              if (order.deliveryMethod != null)
                _Block(
                  'Delivery Method',
                  method?.orderName ?? order.deliveryMethod!,
                  [
                    if (order.deliveryFee != null)
                      'Shipping price : ${moneyLabel(fee)}',
                    if (arrival != null)
                      'Estimated arrival : ${arrivalLabel(arrival)}',
                  ],
                ),
              if (contact != null)
                _Block('Contact Information', contact.name, [
                  contact.email,
                  contact.phone,
                ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: const _DownloadReceiptButton(),
        ),
      ],
    );
  }
}

/// Figma node 3001:9081: a 14px store avatar and name above the quantity,
/// thumbnail, title and line price. The design mixes weights across the
/// title and price; here both use one style each, the same simplification
/// `InfoSummaryRow` already documents for its own grey lines.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CartItem item;

  static const double _thumb = 40;
  static const double _avatar = 14;

  static const TextStyle _storeStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

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

  static const TextStyle _priceStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Row(
          spacing: AppSpacing.xs,
          children: [
            ClipOval(
              child: SizedBox(
                width: _avatar,
                height: _avatar,
                child: product.storeAvatarUrl == null
                    ? const ColoredBox(color: AppColors.blackAlpha10)
                    : CachedNetworkImage(
                        imageUrl: product.storeAvatarUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Text(product.storeName, style: _storeStyle),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('x${item.quantity}', style: _quantityStyle),
            const SizedBox(width: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: _thumb,
                height: _thumb,
                child: product.imageUrl == null
                    ? const ColoredBox(color: AppColors.blackAlpha10)
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(product.title, style: _titleStyle)),
            Text(moneyLabel(item.subtotal), style: _priceStyle),
          ],
        ),
      ],
    );
  }
}

/// Figma nodes 3001:9138/3001:9147/3001:9157: a bold title, then a bold
/// first line and grey lines under it — the same shape
/// `OrderConfirmationScreen`'s private `_block` helper draws, duplicated
/// here rather than shared since both are one-off, screen-private widgets.
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

/// Figma node 3001:9164: an outlined full width button. See the screen's
/// deviation note — it draws the icon and label but does nothing.
class _DownloadReceiptButton extends StatelessWidget {
  const _DownloadReceiptButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: 'Download order receipt',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary400),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            AppIcon(AppIconGlyph.download, color: AppColors.primary400),
            Text(
              'Download order receipt',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeSm,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w500,
                color: AppColors.primary400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
