import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// Reproduces the Figma "Item card" component set (node 874:6024): a
/// cart/list row with a thumbnail, seller info, description, and price,
/// plus a trailing action that differs by context.
///
/// Figma's two variants map to [trailing]: "Default" (Cart) shows a
/// quantity stepper + delete icon, "Variant2" (My collection-products)
/// shows a filled bookmark instead. [ItemCardTrailing.none] reproduces
/// both variants' `showQuantityAndDeleteIcon: false` state. Figma's
/// `showStoreName` prop is reproduced simply by leaving [storeName] null.
enum ItemCardTrailing { quantityStepper, saved, none }

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.title,
    required this.price,
    this.storeName,
    this.storeAvatarUrl,
    this.imageUrl,
    this.trailing = ItemCardTrailing.quantityStepper,
    this.quantity = 1,
    this.onIncrement,
    this.onDecrement,
    this.onDelete,
    this.onTap,
  });

  final String title;
  final String price;
  final String? storeName;
  final String? storeAvatarUrl;
  final String? imageUrl;
  final ItemCardTrailing trailing;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  static const double _mediaSize = 90;
  static const double _avatarSize = 14;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                _Media(imageUrl: imageUrl, size: _mediaSize),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (storeName != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Avatar(url: storeAvatarUrl, size: _avatarSize),
                            const SizedBox(width: AppSpacing.xs),
                            Text(storeName!, style: _storeNameStyle),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        title,
                        style: _titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        price,
                        style: _priceStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildTrailing(),
        ],
      ),
    );
  }

  Widget _buildTrailing() {
    switch (trailing) {
      case ItemCardTrailing.quantityStepper:
        return _QuantityStepper(
          quantity: quantity,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
          onDelete: onDelete,
        );
      case ItemCardTrailing.saved:
        return const AppIcon(
          AppIconGlyph.saveFilled,
          color: AppColors.neutral1100,
        );
      case ItemCardTrailing.none:
        return const SizedBox.shrink();
    }
  }

  static const TextStyle _storeNameStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1000,
  );

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static const TextStyle _priceStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );
}

class _Media extends StatelessWidget {
  const _Media({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? const ColoredBox(color: AppColors.blackAlpha10)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: AppColors.blackAlpha10),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: AppColors.blackAlpha10,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? const ColoredBox(color: AppColors.neutral200)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: AppColors.neutral200),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: AppColors.neutral200),
              ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;

  // Figma's own gap here (10) isn't a shared spacing token — kept local,
  // consistent with the other one-off gaps found elsewhere in this file.
  static const double _gap = 10;
  static const double _deleteIconSize = 18.75;

  static const TextStyle _stepStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: const Text('-', style: _stepStyle),
        ),
        const SizedBox(width: _gap),
        Text('$quantity', style: _stepStyle),
        const SizedBox(width: _gap),
        GestureDetector(
          onTap: onIncrement,
          child: const Text('+', style: _stepStyle),
        ),
        const SizedBox(width: _gap),
        GestureDetector(
          onTap: onDelete,
          child: const Icon(
            Icons.delete_outline,
            size: _deleteIconSize,
            color: AppColors.error600,
          ),
        ),
      ],
    );
  }
}
