import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Most Visited Item" tile (Home screen, "The design -
/// user" page, node 228:3069) — a store shortcut shown in Home's "Most
/// Visited" grid: a bordered, rounded icon box with the store's logo, and
/// the store name below it.
class MostVisitedItem extends StatelessWidget {
  const MostVisitedItem({
    super.key,
    required this.storeName,
    this.iconUrl,
    this.onTap,
  });

  final String storeName;

  /// Store's logo/brand image. Shown with a storefront fallback icon while
  /// loading, on error, or if null (Figma shows this per-brand — here it's
  /// driven by real seller data).
  final String? iconUrl;

  final VoidCallback? onTap;

  // Layout constants intrinsic to this component (not shared design tokens).
  static const double _boxSize = 56;
  static const double _iconSize = 24;
  static const double _iconLabelGap = 10;
  // Figma tracks this label at 0.24 letterspacing; no shared tracking token
  // exists yet, so it's kept local to this component like the other
  // intrinsic layout constants above.
  static const double _labelLetterSpacing = 0.24;

  static TextStyle get _labelStyle => const TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral500,
    letterSpacing: _labelLetterSpacing,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _boxSize,
            height: _boxSize,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: Center(
              child: SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: iconUrl == null
                    ? const Icon(
                        Icons.storefront_outlined,
                        size: _iconSize,
                        color: AppColors.neutral500,
                      )
                    : CachedNetworkImage(
                        imageUrl: iconUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) =>
                            const SizedBox.shrink(),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.storefront_outlined,
                          size: _iconSize,
                          color: AppColors.neutral500,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: _iconLabelGap),
          Text(
            storeName,
            style: _labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
