import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import '../../data/providers/order_providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/summary_row.dart';
import 'checkout_header.dart';
import 'checkout_logic.dart';

/// Reproduces the Figma Order confirmation page (node 3001:10433); the build
/// spec is `docs/specs/0009-purchasing-flow/index.md` (AC-17 to AC-19). Opened
/// at `/order-confirmation/:id` in place of the Checkout page.
///
/// [isSignedIn] false shows the "Be the first in line" block with its Sign in
/// button. The X, "Go back to home page" and the system Back all go Home,
/// never back to the finished checkout.
///
/// Deviations from the frame (spec 0009): prices read `$45`, the delivery
/// price and arrival date are the ones the order stored (the frame shows a
/// different fee than the checkout), the greeting has no stray spaces, the
/// payment line says "Pay on delivery" for a pay on delivery order, and the
/// device status bar is not built.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.isSignedIn = false,
  });

  final String orderId;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: AppColors.white100,
        body: SafeArea(
          child: Column(
            children: [
              CheckoutHeader(
                title: 'Order Confirmation',
                onClose: () => context.go('/'),
              ),
              Expanded(
                child: order.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _Failed(
                    onHome: () => context.go('/'),
                    onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
                  ),
                  data: (order) => order == null
                      ? _Failed(onHome: () => context.go('/'))
                      : _Body(order: order, isSignedIn: isSignedIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.isSignedIn});

  final Order order;
  final bool isSignedIn;

  static const TextStyle _numberStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral600,
  );

  static const TextStyle _thanksStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.size2xl,
    height: AppTypography.lineHeight2xl,
    fontWeight: FontWeight.w700,
    color: AppColors.primary400,
  );

  static const TextStyle _readyStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _offersTitleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _offersBodyStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1000,
  );

  @override
  Widget build(BuildContext context) {
    final greeting = order.contact == null
        ? 'Thank you for your order!'
        : 'Thank you for your order, ${firstNameOf(order.contact!.name)}!';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              Text(
                '${orderNumberLabel(order.orderNumber)} is confirmed',
                style: _numberStyle,
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(greeting, style: _thanksStyle),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "We'll send you an email and an sms when it's ready",
                style: _readyStyle,
              ),
              if (!isSignedIn) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Be the first in line for exclusive offers.',
                  style: _offersTitleStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Sign in to get early alerts on fresh finds, flash deals & '
                  'hot products.',
                  style: _offersBodyStyle,
                ),
                const SizedBox(height: AppSpacing.base),
                AppButton(
                  label: 'Sign in',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => context.push('/sign-in'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(order: order),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.base),
          color: AppColors.white100,
          child: AppButton(
            label: 'Go back to home page',
            onPressed: () => context.go('/'),
          ),
        ),
      ],
    );
  }
}

/// The bordered card (Figma node 3001:10448): the totals, then contact,
/// address, delivery and payment, each only when the order has it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final Order order;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXl,
    height: AppTypography.lineHeightXl,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral1100,
  );

  static const TextStyle _blockTitleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightLg,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral1100,
  );

  static const TextStyle _boldStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral600,
  );

  static const TextStyle _lineStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral600,
  );

  static const TextStyle _paymentTitleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1000,
  );

  static const TextStyle _paymentStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral1000,
  );

  Widget _block(String title, String first, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Text(title, style: _blockTitleStyle),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(first, style: _boldStyle),
            for (final line in lines) Text(line, style: _lineStyle),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fee = order.deliveryFee ?? 0;
    final subtotal = order.subtotal ?? order.totalAmount - fee;
    final contact = order.contact;
    final address = order.shippingAddress;
    final method = deliveryMethodOf(order.deliveryMethod);
    final arrival = order.estimatedDelivery;
    final byCard = order.paymentMethod == 'card';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral1000),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.base,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              const Text('Order Summary', style: _titleStyle),
              Column(
                spacing: 10,
                children: [
                  SummaryRow(
                    label: 'Order subtotal',
                    value: moneyLabel(subtotal),
                  ),
                  SummaryRow(label: 'Delivery', value: moneyLabel(fee)),
                  SummaryRow(
                    label: 'Total price',
                    value: moneyLabel(order.totalAmount),
                    emphasized: true,
                  ),
                ],
              ),
            ],
          ),
          if (contact != null)
            _block('Contact Information', contact.name, [
              contact.email,
              contact.phone,
            ]),
          if (address != null)
            _block('Shipping Address', address.country, [
              '${address.address}, ${address.city}, ${address.zip}',
              if (address.note.isNotEmpty) address.note,
            ]),
          if (order.deliveryMethod != null)
            _block(
              'Delivery Method',
              method?.orderName ?? order.deliveryMethod!,
              [
                if (order.deliveryFee != null)
                  'Shipping price: ${moneyLabel(fee)}',
                if (arrival != null)
                  'Estimated arrival: ${arrivalLabel(arrival)}',
              ],
            ),
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
                      color: AppColors.neutral1000,
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
        ],
      ),
    );
  }
}

/// The order could not be loaded (or does not exist).
class _Failed extends StatelessWidget {
  const _Failed({required this.onHome, this.onRetry});

  final VoidCallback onHome;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Couldn't load your order.",
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          if (onRetry != null) ...[
            AppButton(label: 'Try again', onPressed: onRetry),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Go back to home page',
            variant: AppButtonVariant.secondary,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}
