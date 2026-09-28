import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/cart_item.dart';
import '../../features/cart/cart_logic.dart';
import 'app_icon.dart';
import 'item_card.dart';

/// Reproduces the Figma "Shipping items" accordion (Dropdown menu component,
/// node 455:3177, variants "Frame 369" collapsed and "Frame 370" expanded):
/// the checkout section that lists what is being shipped, one store header
/// (avatar and name) followed by a row per line with quantity, thumbnail,
/// title and line total.
///
/// Deviations from the design:
/// - The title takes the space left of the price (up to two lines) instead of
///   the fixed 144 wide box, so long titles wrap rather than clip.
/// - Prices read `$40`, like every other screen, where Figma writes `40$`.
/// - Lines of several stores get one store header each, 16 apart. The design
///   only shows one store.
/// - The store name colour `#222` has no token, [AppColors.neutral1000] is used.
class ShippingItemsSection extends StatefulWidget {
  const ShippingItemsSection({
    super.key,
    required this.items,
    this.initiallyExpanded = false,
  });

  final List<CartItem> items;
  final bool initiallyExpanded;

  @override
  State<ShippingItemsSection> createState() => _ShippingItemsSectionState();
}

class _ShippingItemsSectionState extends State<ShippingItemsSection> {
  late bool _expanded = widget.initiallyExpanded;

  static const double _avatarSize = 14;
  static const double _mediaSize = 40;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightLg,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1000,
  );

  static const TextStyle _storeStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1000,
  );

  static const TextStyle _lineStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static const TextStyle _priceStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral600,
  );

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final byStore = <String, List<CartItem>>{};
    for (final item in widget.items) {
      (byStore[item.product.storeId] ??= []).add(item);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.neutral100,
        border: Border(bottom: BorderSide(color: AppColors.neutral200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The vertical padding sits inside the tap area, so the whole
            // 59 high header is the button.
            Semantics(
              button: true,
              expanded: _expanded,
              label: 'Shipping items',
              onTap: _toggle,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _toggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.base,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shipping items', style: _titleStyle),
                      RotatedBox(
                        quarterTurns: _expanded ? 2 : 0,
                        child: const AppIcon(
                          AppIconGlyph.chevronDown,
                          color: AppColors.neutral1000,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.base,
                  children: [
                    for (final lines in byStore.values)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.sm,
                        children: [
                          Row(
                            spacing: AppSpacing.xs,
                            children: [
                              ItemAvatar(
                                url: lines.first.product.storeAvatarUrl,
                                size: _avatarSize,
                              ),
                              Text(
                                lines.first.product.storeName,
                                style: _storeStyle,
                              ),
                            ],
                          ),
                          for (final line in lines)
                            Row(
                              spacing: AppSpacing.sm,
                              children: [
                                Text('x${line.quantity}', style: _lineStyle),
                                ItemMedia(
                                  imageUrl: line.product.imageUrl,
                                  size: _mediaSize,
                                ),
                                Expanded(
                                  child: Text(
                                    line.product.title,
                                    style: _lineStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  cartTotalLabel([line]),
                                  style: _priceStyle,
                                ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
