import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/models/product.dart';
import '../../data/providers/cart_providers.dart';
import 'cart_logic.dart';

/// The one place every Add to cart entry point (product detail, product
/// cards, search rows) goes through, so the out of stock guard and the
/// failure message behave the same everywhere (spec 0007, AC-14, AC-15).
///
/// [size] and [color] fall back to the product's first ones, which is what a
/// quick add picks (AC-11, AC-12). [successMessage] is shown right away,
/// since the cart already shows the change.
Future<void> addToCart(
  BuildContext context,
  Product product, {
  int quantity = 1,
  String? size,
  int? color,
  String? successMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!product.inStock) {
    showCartSnackBar(messenger, 'This item is out of stock');
    return;
  }
  final cart = ProviderScope.containerOf(
    context,
  ).read(cartItemsProvider.notifier);
  final write = cart.add(
    product,
    quantity: quantity,
    size: size ?? firstSize(product),
    color: color ?? firstColor(product),
  );
  if (successMessage != null) showCartSnackBar(messenger, successMessage);
  await guardCartWrite(messenger, write);
}

/// Waits for a cart write and says so when it failed. The notifier has
/// already put the cart back by then.
Future<void> guardCartWrite(
  ScaffoldMessengerState messenger,
  Future<void> write,
) async {
  try {
    await write;
  } catch (_) {
    showCartSnackBar(messenger, "Couldn't update your cart. Try again.");
  }
}

/// A floating pill message, styled like product detail's saved toast. With
/// an [action] it goes away by itself after 4 seconds (AC-6).
void showCartSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.white100,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        duration: Duration(seconds: action == null ? 2 : 4),
        persist: false,
        action: action,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral1100,
          ),
        ),
      ),
    );
}
