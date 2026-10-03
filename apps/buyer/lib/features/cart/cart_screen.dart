import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import '../../data/models/cart_item.dart';
import '../../data/providers/cart_providers.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import 'package:shopscroll_shared/widgets/item_card.dart';
import 'add_to_cart.dart';
import 'cart_logic.dart';

/// Reproduces the Figma "Cart" frame (node 369:362, file
/// `toOakybJ0DaJmU7vcEC0AW`); the build spec and acceptance criteria are in
/// `docs/specs/buyer/0007-cart-interface/index.md`. Opened at `/cart` inside the
/// Home tab, so the bottom tab bar keeps showing under the footer.
///
/// Deviations from the frame (spec 0007): the label reads "Items price"
/// and the total `$170`, matching the app's price style; the total is
/// computed, not the frame's placeholder; each card gains an optional size
/// label and colour dot; the device status bar is not built, the app's own
/// header is used; empty, loading, error and Undo states are not drawn in
/// the frame and follow the app's existing patterns.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: cart.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _Message(
                  text: "Couldn't load your cart.",
                  buttonLabel: 'Try again',
                  onPressed: () => ref.invalidate(cartItemsProvider),
                ),
                data: (items) => items.isEmpty
                    ? _Message(
                        text: 'Your cart is empty',
                        icon: Icons.shopping_cart_outlined,
                        buttonLabel: 'Start shopping',
                        onPressed: () => context.go('/'),
                      )
                    : _Lines(items: sortedByAddedAt(items)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back arrow and a centred "Cart" title.
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
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AppIcon(
                      AppIconGlyph.back,
                      size: 32,
                      color: AppColors.neutral1100,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Cart',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w500,
              color: AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lines, scrolling above a footer with the total and checkout.
class _Lines extends ConsumerWidget {
  const _Lines({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartItemsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    void remove(CartItem item) {
      final write = cart.remove(item.id);
      showCartSnackBar(
        messenger,
        'Removed from cart',
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primary400,
          onPressed: () => guardCartWrite(messenger, cart.undoRemove(item)),
        ),
      );
      guardCartWrite(messenger, write);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xl),
            itemBuilder: (context, index) {
              final item = items[index];
              final product = item.product;
              return ItemCard(
                key: ValueKey(item.id),
                title: product.title,
                price: product.priceLabel,
                storeName: product.storeName,
                storeAvatarUrl: product.storeAvatarUrl,
                imageUrl: product.imageUrl,
                sizeLabel: item.selectedSize == null
                    ? null
                    : 'Size ${item.selectedSize}',
                colorDot: item.selectedColor == null
                    ? null
                    : Color(item.selectedColor!),
                quantity: item.quantity,
                onIncrement: item.quantity < maxCartQuantity
                    ? () => guardCartWrite(
                        messenger,
                        cart.changeQuantity(item.id, 1),
                      )
                    : null,
                onDecrement: item.quantity > 1
                    ? () => guardCartWrite(
                        messenger,
                        cart.changeQuantity(item.id, -1),
                      )
                    : null,
                onDelete: () => remove(item),
                onTap: () => context.push('/product/${product.id}'),
              );
            },
          ),
        ),
        _Footer(items: items),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.items});

  final List<CartItem> items;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXl,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: const BoxDecoration(
        color: AppColors.white100,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items price', style: _labelStyle),
              Text(cartTotalLabel(items), style: _labelStyle),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Proceed to checkout',
              onPressed: () => context.push('/checkout'),
            ),
          ),
        ],
      ),
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
