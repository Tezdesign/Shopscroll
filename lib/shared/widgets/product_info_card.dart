import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Product Info" tile (Home screen, "The design - user"
/// page, node 141:2293) — the compact 4-up row at the top of the Home
/// screen's product feed. Unlike [ProductCard], this tile has no price, no
/// color swatches, and no add-to-cart button: just seller avatar+name, media,
/// and a 2-line description.
///
/// This isn't a formally published Figma component (it's a hand-duplicated
/// frame repeated 4 times), but the composition is identical across all four
/// instances, so it's reproduced here as a proper reusable widget.
class ProductInfoCard extends StatelessWidget {
  const ProductInfoCard({
    super.key,
    required this.storeName,
    required this.description,
    this.storeAvatarUrl,
    this.imageUrl,
    this.onTap,
  });

  final String storeName;
  final String description;
  final String? storeAvatarUrl;
  final String? imageUrl;
  final VoidCallback? onTap;

  // Layout constants intrinsic to this component (not shared design tokens).
  static const double _cardWidth = 110.625;
  static const double _mediaHeight = 198.75;
  static const double _avatarSize = 14;
  // Figma's own gap between the header/media/description rows (2px) is
  // tighter than the smallest shared spacing token (AppSpacing.xs = 4),
  // so it's kept as a component-local constant rather than forced onto a token.
  static const double _rowGap = 2;

  static TextStyle get _storeNameStyle => const TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1000,
  );

  static TextStyle get _descriptionStyle => const TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(url: storeAvatarUrl, size: _avatarSize),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    storeName,
                    style: _storeNameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _rowGap),
            _Media(imageUrl: imageUrl, height: _mediaHeight),
            const SizedBox(height: _rowGap),
            Text(
              description,
              style: _descriptionStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
