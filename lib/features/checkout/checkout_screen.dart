import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/contact_info.dart';
import '../../data/models/place_order_request.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/cart_providers.dart';
import '../../data/providers/checkout_providers.dart';
import '../../data/providers/order_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/repository_providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/checkout_section.dart';
import '../../shared/widgets/delivery_method_tile.dart';
import '../../shared/widgets/payment_option_row.dart';
import '../../shared/widgets/shipping_items_section.dart';
import '../../shared/widgets/summary_row.dart';
import '../cart/add_to_cart.dart';
import '../cart/cart_logic.dart';
import 'address_sheet.dart';
import 'checkout_header.dart';
import 'checkout_logic.dart';
import 'contact_sheet.dart';

/// Reproduces the Figma Checkout page (node 3001:9830 and its filled states
/// 3001:9956, 3001:10085); the build spec and acceptance criteria are in
/// `docs/specs/0009-purchasing-flow/index.md`. Opened at `/checkout` above the
/// tab bar (full screen), from the cart's "Proceed to checkout".
///
/// [signedInUserId] is set for a signed in buyer: their profile then fills the
/// contact (AC-5). Signed out buyers, and the mock backend, start empty.
///
/// Deviations from the frame (spec 0009): the discount code field takes text
/// but Apply looks disabled and does nothing (codes come with their own
/// spec), there is no discount line, and Pay by Credit Card can be chosen but
/// opens no card sheet and cannot place an order yet. The device status bar is
/// not built. Prices read `$45` where Figma writes `45$`.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, this.signedInUserId});

  final String? signedInUserId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _discountCode = TextEditingController();
  bool _placing = false;

  // What the profile holds, even when it is not enough to fill the contact
  // section. It still fills the sheet's fields.
  ContactInfo? _profileContact;

  @override
  void initState() {
    super.initState();
    final userId = widget.signedInUserId;
    if (userId != null) {
      ref.listenManual(
        userProfileByIdProvider(userId),
        (previous, next) => _prefill(next.value),
      );
      // Riverpod does not allow changing a provider while the tree builds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefill(ref.read(userProfileByIdProvider(userId)).value);
      });
    }
  }

  @override
  void dispose() {
    _discountCode.dispose();
    super.dispose();
  }

  void _prefill(UserProfile? profile) {
    if (profile == null) return;
    final contact = ContactInfo(
      name: profile.name,
      email: profile.email ?? '',
      phone: profile.phone ?? '',
    );
    _profileContact = contact;
    if (isContactValid(contact)) {
      ref.read(checkoutDraftProvider.notifier).prefillContact(contact);
    }
  }

  Future<void> _editContact() async {
    final draft = ref.read(checkoutDraftProvider);
    final contact = await showContactSheet(
      context,
      initial: draft.contact ?? _profileContact,
    );
    if (contact != null) {
      ref.read(checkoutDraftProvider.notifier).setContact(contact);
    }
  }

  Future<void> _editAddress() async {
    final draft = ref.read(checkoutDraftProvider);
    final address = await showAddressSheet(context, initial: draft.address);
    if (address != null) {
      ref.read(checkoutDraftProvider.notifier).setAddress(address);
    }
  }

  /// The X and the system back: asks first when something was entered (AC-14).
  Future<void> _close() async {
    if (ref.read(checkoutDraftProvider).touched) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard your details?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/cart');
  }

  Future<void> _placeOrder() async {
    final draft = ref.read(checkoutDraftProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (!draft.isComplete || _placing) return;
    if (draft.paymentMethod == PaymentMethod.card) {
      showCartSnackBar(messenger, 'Card payment is coming soon');
      return;
    }
    // Taken before the await: this screen is gone when the order lands.
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    final items = ref.read(cartItemsProvider).value ?? const <CartItem>[];

    setState(() => _placing = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            PlaceOrderRequest(
              orderId: ref.read(checkoutDraftProvider.notifier).orderId,
              contact: draft.contact!,
              address: draft.address!,
              deliveryMethod: draft.deliveryMethod!,
              paymentMethod: draft.paymentMethod!,
              expectedSubtotal: cartTotal(items),
            ),
          );
      // Replace this page, so Back never returns to a finished checkout.
      router.pushReplacement('/order-confirmation/${order.id}');
      container.invalidate(cartItemsProvider);
      container.invalidate(ordersProvider);
    } on PlaceOrderException catch (error) {
      showCartSnackBar(messenger, placeOrderFailureMessage(error.reason));
      if (error.reason == PlaceOrderFailure.itemsChanged ||
          error.reason == PlaceOrderFailure.cartEmpty) {
        container.invalidate(cartItemsProvider);
      }
    } catch (_) {
      showCartSnackBar(
        messenger,
        placeOrderFailureMessage(PlaceOrderFailure.failed),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartItemsProvider);
    final touched = ref.watch(checkoutDraftProvider.select((d) => d.touched));

    return PopScope(
      canPop: !touched,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.white100,
        body: SafeArea(
          child: Column(
            children: [
              CheckoutHeader(title: 'Checkout', onClose: _close),
              Expanded(
                child: cart.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _Message(
                    text: "Couldn't load your cart.",
                    buttonLabel: 'Try again',
                    onPressed: () => ref.invalidate(cartItemsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? _Message(
                          text: 'Your cart is empty',
                          icon: Icons.shopping_cart_outlined,
                          buttonLabel: 'Back to cart',
                          onPressed: () => context.go('/cart'),
                        )
                      : _Form(
                          items: sortedByAddedAt(items),
                          discountCode: _discountCode,
                          placing: _placing,
                          onEditContact: _editContact,
                          onEditAddress: _editAddress,
                          onPlaceOrder: _placeOrder,
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

/// The sections, scrolling above the pinned Place order button.
class _Form extends ConsumerWidget {
  const _Form({
    required this.items,
    required this.discountCode,
    required this.placing,
    required this.onEditContact,
    required this.onEditAddress,
    required this.onPlaceOrder,
  });

  final List<CartItem> items;
  final TextEditingController discountCode;
  final bool placing;
  final VoidCallback onEditContact;
  final VoidCallback onEditAddress;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(checkoutDraftProvider);
    final notifier = ref.read(checkoutDraftProvider.notifier);
    final subtotal = cartTotal(items);
    final method = draft.deliveryMethod;
    final contact = draft.contact;
    final address = draft.address;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            children: [
              ShippingItemsSection(items: items, initiallyExpanded: true),
              const SizedBox(height: AppSpacing.base),
              CheckoutSection(
                title: 'Contact information',
                child: contact == null
                    ? AddInfoRow(
                        label: 'Add your contact info',
                        onTap: onEditContact,
                      )
                    : InfoSummaryRow(
                        title: contact.name,
                        lines: [contact.email, contact.phone],
                        editLabel: 'Edit contact information',
                        onEdit: onEditContact,
                      ),
              ),
              const SizedBox(height: AppSpacing.base),
              CheckoutSection(
                title: 'Delivery address',
                child: address == null
                    ? AddInfoRow(
                        label: 'Add your address',
                        onTap: onEditAddress,
                      )
                    : InfoSummaryRow(
                        title: address.country,
                        lines: [
                          address.line,
                          if (address.note.isNotEmpty) address.note,
                        ],
                        editLabel: 'Edit delivery address',
                        onEdit: onEditAddress,
                      ),
              ),
              const SizedBox(height: AppSpacing.base),
              CheckoutSection(
                title: 'Delivery Method',
                child: Column(
                  spacing: AppSpacing.base,
                  children: [
                    for (final option in DeliveryMethod.values)
                      DeliveryMethodTile(
                        title: option.title,
                        priceLabel: moneyLabel(option.fee),
                        selected: method == option,
                        onTap: () => notifier.setDeliveryMethod(option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              CheckoutSection(
                title: 'Order Summary',
                topBorder: true,
                child: Column(
                  spacing: 10,
                  children: [
                    Row(
                      spacing: 10,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: discountCode,
                            hintText: 'Discount code',
                          ),
                        ),
                        const AppButton(
                          label: 'Apply',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          enabled: false,
                        ),
                      ],
                    ),
                    SummaryRow(
                      label: 'Order subtotal',
                      value: moneyLabel(subtotal),
                    ),
                    SummaryRow(
                      label: 'Delivery',
                      value: method == null
                          ? 'Not chosen'
                          : moneyLabel(method.fee),
                    ),
                    SummaryRow(
                      label: 'Price to pay',
                      value: moneyLabel(orderTotal(subtotal, method?.fee)),
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              CheckoutSection(
                title: 'Payment method',
                topBorder: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaymentOptionRow(
                      label: 'Pay by Credit Card',
                      icon: Icons.lock_outline,
                      selected: draft.paymentMethod == PaymentMethod.card,
                      onTap: () =>
                          notifier.setPaymentMethod(PaymentMethod.card),
                      footer: const _CardLogos(),
                    ),
                    PaymentOptionRow(
                      label: 'Pay on delivery',
                      selected:
                          draft.paymentMethod == PaymentMethod.cashOnDelivery,
                      onTap: () => notifier.setPaymentMethod(
                        PaymentMethod.cashOnDelivery,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.base),
          color: AppColors.white100,
          child: AppButton(
            label: placing ? 'Placing order' : 'Place order',
            enabled: draft.isComplete && !placing,
            onPressed: onPlaceOrder,
          ),
        ),
      ],
    );
  }
}

/// The four accepted card brands (Figma nodes 3001:9886, 3001:9897,
/// 3001:9909, 3001:9918), each a 50 by 32 image exported from the design.
class _CardLogos extends StatelessWidget {
  const _CardLogos();

  static const _logos = [
    'assets/icons/card_mastercard.png',
    'assets/icons/card_maestro.png',
    'assets/icons/card_visa.png',
    'assets/icons/card_discover.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.xs,
      children: [
        for (final path in _logos)
          Image.asset(path, width: 50, height: 32, excludeFromSemantics: true),
      ],
    );
  }
}

/// Centred message with one button: the empty and error states.
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: AppColors.neutral400),
            const SizedBox(height: AppSpacing.base),
          ],
          Text(
            text,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(label: buttonLabel, onPressed: onPressed),
        ],
      ),
    );
  }
}
