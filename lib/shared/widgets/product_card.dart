import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma component "Product card" (Design System-mobile,
/// node 717:3401, variants `big size` / `meidum size` / `tech`).
///
/// The `medium` and `tech` Figma variants render identically (the `tech`
/// variant only stacks a second, same-sized image over the first — a
/// leftover from the source file that has no visible effect), so both map
/// to [ProductCardSize.medium] here.
enum ProductCardSize { big, medium }

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.storeName,
    this.imageUrl,
    this.storeAvatarUrl,
    this.colorOptions = const <Color>[],
    this.size = ProductCardSize.big,
    this.showAddToCart = true,
    this.onTap,
    this.onAddToCart,
  });

  /// Product description line shown under the store row (Figma: `description`).
  final String title;

  /// Pre-formatted price string, e.g. `"\$40"` (Figma: `$40`).
  final String price;

  final String storeName;
  final String? storeAvatarUrl;

  /// Product media. Shown with a neutral placeholder while loading or if null/failed.
  final String? imageUrl;

  /// Available product color variants, rendered as small swatches next to
  /// the store row (Figma shows these as a static image; here they're
  /// driven by real data since a product's color options vary per item).
  final List<Color> colorOptions;

  final ProductCardSize size;
  final bool showAddToCart;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  // Layout constants intrinsic to this component (not shared design tokens).
  static const double _mediaHeight = 147;
  static const double _bigWidth = 172.5;
  static const double _compactWidth = 135;
  static const double _avatarSize = 14;
  static const double _swatchSize = 10;
  static const double _compactHeaderGap = 10;

  double get _cardWidth =>
      size == ProductCardSize.big ? _bigWidth : _compactWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Media(imageUrl: imageUrl, height: _mediaHeight),
            const SizedBox(height: AppSpacing.sm),
            _Details(
              title: title,
              price: price,
              storeName: storeName,
              storeAvatarUrl: storeAvatarUrl,
              colorOptions: colorOptions,
              compact: size == ProductCardSize.medium,
              avatarSize: _avatarSize,
              swatchSize: _swatchSize,
              compactHeaderGap: _compactHeaderGap,
            ),
            if (showAddToCart) ...[
              const SizedBox(height: AppSpacing.sm),
              _AddToCartButton(onPressed: onAddToCart),
            ],
          ],
        ),
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: imageUrl == null
            ? const _MediaPlaceholder()
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _MediaPlaceholder(
                  child: SizedBox(
                    width: AppSpacing.xl,
                    height: AppSpacing.xl,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => const _MediaPlaceholder(
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

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.blackAlpha10,
      child: Center(
        child:
            child ??
            const Icon(Icons.image_outlined, color: AppColors.neutral500),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.title,
    required this.price,
    required this.storeName,
    required this.storeAvatarUrl,
    required this.colorOptions,
    required this.compact,
    required this.avatarSize,
    required this.swatchSize,
    required this.compactHeaderGap,
  });

  final String title;
  final String price;
  final String storeName;
  final String? storeAvatarUrl;
  final List<Color> colorOptions;
  final bool compact;
  final double avatarSize;
  final double swatchSize;
  final double compactHeaderGap;

  static TextStyle get _storeNameStyle => TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1000,
  );

  static TextStyle get _descriptionStyle => TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static TextStyle get _priceStyle => TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    final header = Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(url: storeAvatarUrl, size: avatarSize),
            const SizedBox(width: AppSpacing.xs),
            Text(storeName, style: _storeNameStyle),
          ],
        ),
        if (compact) SizedBox(width: compactHeaderGap),
        if (colorOptions.isNotEmpty)
          _ColorSwatches(colors: colorOptions, size: swatchSize),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: _descriptionStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        Text(
          price,
          style: _priceStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colors, required this.size});

  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in colors) ...[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (color != colors.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'Add to cart',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeSm,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w500,
              color: AppColors.neutral1000,
            ),
          ),
        ),
      ),
    );
  }
}
