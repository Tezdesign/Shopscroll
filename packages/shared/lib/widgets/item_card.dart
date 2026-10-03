import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
    this.sizeLabel,
    this.colorDot,
    this.trailing = ItemCardTrailing.quantityStepper,
    this.quantity = 1,
    this.onIncrement,
    this.onDecrement,
    this.onDelete,
    this.onUnsave,
    this.onTap,
  });

  final String title;
  final String price;
  final String? storeName;
  final String? storeAvatarUrl;
  final String? imageUrl;

  /// Chosen size and colour of a cart line, so two lines of one product can
  /// be told apart. Not in the Figma component (spec 0007's deviations).
  final String? sizeLabel;
  final Color? colorDot;
  final ItemCardTrailing trailing;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;

  /// Tapped on the filled bookmark of the [ItemCardTrailing.saved] variant.
  final VoidCallback? onUnsave;
  final VoidCallback? onTap;

  static const double _mediaSize = 90;
  static const double _avatarSize = 14;
  static const double _dotSize = 10;

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
                ItemMedia(imageUrl: imageUrl, size: _mediaSize),
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
                            ItemAvatar(url: storeAvatarUrl, size: _avatarSize),
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
                      if (sizeLabel != null || colorDot != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sizeLabel != null)
                              Text(sizeLabel!, style: _storeNameStyle),
                            if (sizeLabel != null && colorDot != null)
                              const SizedBox(width: AppSpacing.sm),
                            if (colorDot != null)
                              Container(
                                width: _dotSize,
                                height: _dotSize,
                                decoration: BoxDecoration(
                                  color: colorDot,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.neutral300,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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
        return _Control(
          label: 'Remove from saved',
          onTap: onUnsave,
          child: const AppIcon(
            AppIconGlyph.saveFilled,
            color: AppColors.neutral1100,
          ),
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

class ItemMedia extends StatelessWidget {
  const ItemMedia({super.key, required this.imageUrl, required this.size});

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

class ItemAvatar extends StatelessWidget {
  const ItemAvatar({super.key, required this.url, required this.size});

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
        _Control(
          label: 'Decrease quantity',
          onTap: onDecrement,
          child: const Text('-', style: _stepStyle),
        ),
        Semantics(
          label: 'Quantity',
          value: '$quantity',
          excludeSemantics: true,
          child: Text('$quantity', style: _stepStyle),
        ),
        _Control(
          label: 'Increase quantity',
          onTap: onIncrement,
          child: const Text('+', style: _stepStyle),
        ),
        _Control(
          label: 'Remove from cart',
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

/// One stepper control: a spoken label and a 44 by 44 tap area (spec 0007,
/// AC-17), dimmed when it has no action. The Figma controls are smaller and
/// separated by a 10 gap, the tap area now supplies that space.
class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  static const double _tapSize = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _tapSize,
          height: _tapSize,
          child: Center(
            child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
          ),
        ),
      ),
    );
  }
}
