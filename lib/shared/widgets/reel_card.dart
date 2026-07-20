import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/reel.dart';

/// Reproduces the Figma "Reels" grid tile (node 234:646's repeating
/// Frame 219/220/221/222 children): a store avatar + name row, a thumbnail
/// image, and a caption underneath.
///
/// Width (172.5) matches [ProductCard]'s `big` variant so two [ReelCard]s
/// plus the shared [AppSpacing.base] gap exactly fill this screen's content
/// width (393 - 2*16 padding = 361), the same trick already used on Product
/// detail's "More to see" section.
///
/// An unavailable reel (`isAvailable: false`, see spec 0002 AC-3) renders
/// dimmed and grayscale with a "No longer available" label, and [onTap] is
/// never invoked for it regardless of whether a callback was supplied.
class ReelCard extends StatelessWidget {
  const ReelCard({super.key, required this.reel, this.onTap});

  final Reel reel;
  final VoidCallback? onTap;

  static const double _width = 172.5;
  // Figma's thumbnail is 160x300 (a 8:15 ratio), scaled to this card's width.
  static const double _imageAspectRatio = 160 / 300;

  // Standard luminance weighted grayscale matrix (ITU-R BT.709 coefficients).
  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final unavailable = !reel.isAvailable;

    return SizedBox(
      width: _width,
      child: GestureDetector(
        onTap: unavailable ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoreRow(reel: reel, dimmed: unavailable),
            const SizedBox(height: AppSpacing.xs),
            _Thumbnail(reel: reel, unavailable: unavailable),
            const SizedBox(height: AppSpacing.xs),
            Text(
              reel.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXs,
                height: AppTypography.lineHeightXs,
                fontWeight: FontWeight.w500,
                color: unavailable
                    ? AppColors.neutral500
                    : AppColors.neutral1000,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.reel, required this.dimmed});

  final Reel reel;
  final bool dimmed;

  static const double _avatarSize = 14;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: reel.storeAvatarUrl == null
                ? const ColoredBox(color: AppColors.neutral200)
                : CachedNetworkImage(
                    imageUrl: reel.storeAvatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.neutral200),
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.neutral200),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          reel.storeName,
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeXs,
            height: AppTypography.lineHeightXs,
            fontWeight: FontWeight.w500,
            color: dimmed ? AppColors.neutral500 : AppColors.neutral1000,
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.reel, required this.unavailable});

  final Reel reel;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: ReelCard._imageAspectRatio,
        child: CachedNetworkImage(
          imageUrl: reel.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const ColoredBox(color: AppColors.blackAlpha10),
          errorWidget: (context, url, error) =>
              const ColoredBox(color: AppColors.blackAlpha10),
        ),
      ),
    );

    if (!unavailable) return image;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(ReelCard._grayscaleMatrix),
          child: Opacity(opacity: 0.6, child: image),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutral1100.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text(
                'No longer available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeXs,
                  height: AppTypography.lineHeightXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white100,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
