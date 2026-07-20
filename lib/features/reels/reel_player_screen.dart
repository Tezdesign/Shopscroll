import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/reel.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/reel_providers.dart';
import '../../shared/widgets/app_icon.dart';

/// The full screen, swipeable Reels video player. Reproduces the Figma frame
/// "Scrolling reels" (node 238:2202), found after this screen's first build
/// (that build's own comment, and spec 0002's context section, both said no
/// frame for this state existed; that was true only until this node was
/// found). Two deliberate deviations from that frame, both to keep this
/// spec's already accepted acceptance criteria intact: the like/comment rail
/// labels stay live counts, not the frame's static "like"/"Chat" words (AC-5
/// requires a count), and a share action stays in the rail even though the
/// frame's crop doesn't show one (AC-5 requires it). The frame's standalone
/// mute icon is dropped as redundant, not missing: tapping anywhere on the
/// video already toggles mute (AC-5's "a tap or an icon toggle", either
/// satisfies it). Full build spec and acceptance criteria:
/// `docs/specs/0002-reels-screen.md`.
///
/// Opens on [initialReelId], paging vertically through [orderedReelIds] (the
/// grid's current, possibly search-filtered order) if provided, else every
/// available reel. Unavailable reels are excluded from the pageable list
/// itself, not just dimmed, so swiping can never land on one (AC-4).
///
/// Only a three wide window of `VideoPlayerController`/`ChewieController`
/// instances (current page, one before, one after) is ever alive at once —
/// bounded memory regardless of feed length, matching this spec's Option 1.
/// Like/save state lives once here, in this screen's own [State] (not per
/// page), so it survives swiping away and back within the same session and
/// only resets when this screen is left and reopened (AC-7).
class ReelPlayerScreen extends ConsumerStatefulWidget {
  const ReelPlayerScreen({
    super.key,
    required this.initialReelId,
    this.orderedReelIds,
  });

  final String initialReelId;
  final List<String>? orderedReelIds;

  @override
  ConsumerState<ReelPlayerScreen> createState() => _ReelPlayerScreenState();
}

class _ReelPlayerScreenState extends ConsumerState<ReelPlayerScreen> {
  bool _started = false;
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _muted = true;

  final Map<int, _ReelControllerEntry> _controllers = {};
  final Set<String> _likedIds = {};
  final Set<String> _savedToggled = {};

  @override
  void dispose() {
    if (_started) _pageController.dispose();
    for (final entry in _controllers.values) {
      entry.dispose();
    }
    super.dispose();
  }

  List<Reel> _resolvePageableReels(List<Reel> allReels) {
    final available = {
      for (final r in allReels)
        if (r.isAvailable) r.id: r,
    };
    final ids = widget.orderedReelIds ?? available.keys.toList();
    return [for (final id in ids) if (available[id] != null) available[id]!];
  }

  bool _isLiked(Reel reel) => _likedIds.contains(reel.id);

  bool _isSaved(Reel reel) =>
      _savedToggled.contains(reel.id) ? !reel.isSaved : reel.isSaved;

  int _likeCount(Reel reel) => reel.likeCount + (_isLiked(reel) ? 1 : 0);

  void _toggleLike(Reel reel) {
    setState(() {
      if (!_likedIds.add(reel.id)) _likedIds.remove(reel.id);
    });
  }

  void _toggleSave(Reel reel) {
    setState(() {
      if (!_savedToggled.add(reel.id)) _savedToggled.remove(reel.id);
    });
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    for (final entry in _controllers.values) {
      if (entry.videoController.value.isInitialized) {
        entry.videoController.setVolume(_muted ? 0 : 1);
      }
    }
  }

  void _syncPlayback() {
    for (final MapEntry(key: index, value: entry) in _controllers.entries) {
      final controller = entry.videoController;
      if (!controller.value.isInitialized) continue;
      if (index == _currentIndex) {
        controller.play();
      } else {
        controller.pause();
      }
    }
  }

  void _ensureWindow(List<Reel> reels) {
    final window = <int>{
      if (_currentIndex - 1 >= 0) _currentIndex - 1,
      _currentIndex,
      if (_currentIndex + 1 < reels.length) _currentIndex + 1,
    };

    for (final index in window) {
      if (!_controllers.containsKey(index)) {
        _createController(index, reels[index]);
      }
    }

    final toRemove = _controllers.keys
        .where((index) => !window.contains(index))
        .toList();
    for (final index in toRemove) {
      _controllers.remove(index)?.dispose();
    }

    _syncPlayback();
  }

  Future<void> _createController(int index, Reel reel) async {
    final videoController = VideoPlayerController.networkUrl(
      Uri.parse(reel.videoUrl),
    );
    final entry = _ReelControllerEntry(videoController);
    // Reserve the slot immediately (before the await below) so a fast swipe
    // back and forth can't trigger a second, concurrent create for the same
    // index.
    _controllers[index] = entry;

    try {
      await videoController.initialize();
    } catch (_) {
      entry.failed = true;
      if (mounted) setState(() {});
      return;
    }

    if (entry.disposed) {
      // The active window moved past this index while its video was still
      // initializing. Only dispose now, after initialize() has actually
      // settled — disposing mid-initialize is the video_player race this
      // screen has to guard against explicitly.
      await videoController.dispose();
      return;
    }

    videoController
      ..setLooping(true)
      ..setVolume(_muted ? 0 : 1);
    entry.chewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: false,
      looping: true,
      showControls: false,
    );

    if (!mounted) return;
    setState(() {});
    _syncPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(reelsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, stackTrace) => const _CenteredMessage(
          text: "Couldn't load this reel.",
        ),
        data: (allReels) {
          final reels = _resolvePageableReels(allReels);
          if (reels.isEmpty) {
            return const _CenteredMessage(text: 'No reels to show.');
          }

          if (!_started) {
            final initial = reels.indexWhere(
              (r) => r.id == widget.initialReelId,
            );
            _currentIndex = initial >= 0 ? initial : 0;
            _pageController = PageController(initialPage: _currentIndex);
            _started = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _ensureWindow(reels),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _ensureWindow(reels);
                },
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  return _ReelPage(
                    reel: reel,
                    entry: _controllers[index],
                    liked: _isLiked(reel),
                    likeCount: _likeCount(reel),
                    saved: _isSaved(reel),
                    onToggleLike: () => _toggleLike(reel),
                    onToggleSave: () => _toggleSave(reel),
                    onToggleMute: _toggleMute,
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.sm,
                  ),
                  child: _CloseButton(onTap: () => context.pop()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Holds one page's `VideoPlayerController`/`ChewieController` pair.
/// [disposed] guards the initialize-then-dispose race: a page can leave the
/// active window while its controller is still mid `initialize()`, so
/// [dispose] must be safe to call at any point, and [_createController]
/// must check [disposed] after `await`ing initialize before touching the
/// controller further.
class _ReelControllerEntry {
  _ReelControllerEntry(this.videoController);

  final VideoPlayerController videoController;
  ChewieController? chewieController;
  bool disposed = false;
  bool failed = false;

  void dispose() {
    if (disposed) return;
    disposed = true;
    chewieController?.dispose();
    videoController.dispose();
  }
}

/// One page of the player: video surface, tap-to-unmute, action rail, and
/// bottom overlay. A [StatelessWidget] by design — all state that must
/// outlive this page (like/save, the controller itself) is lifted to
/// [_ReelPlayerScreenState], since `PageView` disposes offscreen pages.
class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.reel,
    required this.entry,
    required this.liked,
    required this.likeCount,
    required this.saved,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onToggleMute,
  });

  final Reel reel;
  final _ReelControllerEntry? entry;
  final bool liked;
  final int likeCount;
  final bool saved;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final videoController = entry?.videoController;
    final ready = videoController?.value.isInitialized ?? false;

    return GestureDetector(
      onTap: onToggleMute,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: reel.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const ColoredBox(color: Colors.black),
            errorWidget: (context, url, error) =>
                const ColoredBox(color: Colors.black),
          ),
          if (ready)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoController!.value.size.width,
                  height: videoController.value.size.height,
                  child: VideoPlayer(videoController),
                ),
              ),
            ),
          if (!ready && entry?.failed != true)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (ready)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: videoController!,
              builder: (context, value, child) => value.isBuffering
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const SizedBox.shrink(),
            ),
          // A soft bottom gradient so the caption/overlay text stays legible
          // over a bright video frame, a common short-form-video convention
          // not shown in any Figma frame for this (undesigned) state.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _BottomOverlay(reel: reel)),
                      const SizedBox(width: AppSpacing.sm),
                      _ActionRail(
                        liked: liked,
                        likeCount: likeCount,
                        commentCount: reel.commentCount,
                        saved: saved,
                        onToggleLike: onToggleLike,
                        onToggleSave: onToggleSave,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (ready)
                    VideoProgressIndicator(
                      videoController!,
                      allowScrubbing: false,
                      padding: EdgeInsets.zero,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.white100,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    )
                  else
                    const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Store avatar/name, static "Follow" button, caption, and (Figma node
/// 238:2202's "banner") the tagged product promo card, when the reel has
/// tagged products (Build plan task 6/7, AC-5/AC-6).
class _BottomOverlay extends StatelessWidget {
  const _BottomOverlay({required this.reel});

  final Reel reel;

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reel.productIds.isNotEmpty) ...[
          _ProductPromoCard(reel: reel),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                width: _avatarSize,
                height: _avatarSize,
                child: reel.storeAvatarUrl == null
                    ? const ColoredBox(color: AppColors.neutral400)
                    : CachedNetworkImage(
                        imageUrl: reel.storeAvatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.neutral400),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: AppColors.neutral400),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                reel.storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeBase,
                  height: AppTypography.lineHeightBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white100,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Static: no follow/social graph model exists yet in this app
            // (see spec 0002 Follow-up); wiring this is out of scope here.
            const _FollowButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          reel.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightSm,
            fontWeight: FontWeight.w400,
            color: AppColors.white100,
          ),
        ),
      ],
    );
  }
}

/// The tagged-product promo card (Figma node 238:2266, "banner"): shows the
/// reel's first tagged product inline over the video, rather than hiding it
/// behind a tap-to-reveal pill. Tapping the card (or its cart icon) opens
/// the same "every tagged product" sheet AC-6 already requires; "Buy now" is
/// the frame's own quick action, jumping straight to that one product's
/// detail page. A [ConsumerWidget] (not [_ReelPage] itself) so only this
/// card re-renders while `productsProvider` resolves.
class _ProductPromoCard extends ConsumerWidget {
  const _ProductPromoCard({required this.reel});

  final Reel reel;

  static const double _imageSize = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final products = productsAsync.asData?.value ?? const <Product>[];
    Product? product;
    for (final p in products) {
      if (reel.productIds.contains(p.id)) {
        product = p;
        break;
      }
    }
    if (product == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showShopTheLookSheet(context, reel),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.white100,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: _imageSize,
                height: _imageSize,
                child: product.imageUrl == null
                    ? const ColoredBox(color: AppColors.blackAlpha10)
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeXs,
                      height: AppTypography.lineHeightXs,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral1100,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        product.priceLabel,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyBody,
                          fontSize: AppTypography.sizeBase,
                          height: AppTypography.lineHeightBase,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutral1000,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showShopTheLookSheet(context, reel),
                        behavior: HitTestBehavior.opaque,
                        child: const AppIcon(
                          AppIconGlyph.cart,
                          size: 24,
                          color: AppColors.neutral1000,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: () => context.push('/product/${product!.id}'),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary400,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Text(
                            'Buy now',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamilyDisplay,
                              fontSize: AppTypography.sizeSm,
                              height: AppTypography.lineHeightSm,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white100,
                            ),
                          ),
                        ),
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

/// A small white-outlined pill. [AppButton]'s variants all assume a light
/// background (solid or bordered primary400), which reads poorly over a
/// video frame, so this overlay gets its own minimal static button instead
/// of reusing that component — same reasoning already documented for
/// one-off deviations elsewhere in this app.
class _FollowButton extends StatelessWidget {
  const _FollowButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.white100),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: const Text(
        'Follow',
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeXs,
          height: AppTypography.lineHeightXs,
          fontWeight: FontWeight.w600,
          color: AppColors.white100,
        ),
      ),
    );
  }
}

/// Right side like/save/comment rail, matching the order and 24px icon
/// sizing of Figma node 238:2212's rail exactly. Two departures from that
/// frame, both to keep spec 0002's AC-5 intact rather than the frame's own
/// static word labels: like and comment show a live count, not the literal
/// words "like"/"Chat", and a share button is appended after comment even
/// though the frame's crop doesn't show one (AC-5 requires it). The frame's
/// own standalone mute icon isn't reproduced: [_ReelPage] already toggles
/// mute on any tap on the video itself, so a second control would be
/// redundant chrome, not a missing one.
///
/// [AppIconGlyph] has no heart or share glyph (confirmed against its 32
/// entries), so like and share fall back to the semantically closest
/// Material icons directly, the same fallback reasoning already documented
/// on [AppIcon] itself for glyphs it doesn't cover. Save reuses the
/// registry's existing bookmark glyphs, and comment reuses its chat glyph.
class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.saved,
    required this.onToggleLike,
    required this.onToggleSave,
  });

  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool saved;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? AppColors.error400 : AppColors.white100,
          label: '$likeCount',
          onTap: onToggleLike,
        ),
        const SizedBox(height: AppSpacing.xl),
        _RailButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          color: AppColors.white100,
          label: 'Save',
          onTap: onToggleSave,
        ),
        const SizedBox(height: AppSpacing.xl),
        _RailButton(
          icon: Icons.chat_bubble_outline,
          color: AppColors.white100,
          label: '$commentCount',
          onTap: null,
        ),
        const SizedBox(height: AppSpacing.xl),
        _RailButton(
          icon: Icons.share_outlined,
          color: AppColors.white100,
          label: null,
          // Not wired: this app has no real share target to hand off to.
          onTap: () {},
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXs,
                height: AppTypography.lineHeightXs,
                fontWeight: FontWeight.w400,
                color: AppColors.white100,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma node 238:2201's top-left "back" icon over the video, not the
/// previous build's X-in-a-circle. Kept as a plain icon (no background
/// chip) to match that frame; still pops the route like the button it
/// replaces.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: AppIcon(
            AppIconGlyph.back,
            size: 28,
            color: AppColors.white100,
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            color: AppColors.white100,
          ),
        ),
      ),
    );
  }
}

/// Opens the "shop the look" bottom sheet (AC-6): every product tagged on
/// [reel], tapping through to the existing `/product/:id` route. Reuses the
/// same rounded-top modal sheet chrome Product detail's sheets already
/// established (`showProductDetailsSheet`/`showRefundPolicySheet`); that
/// helper is private to `product_detail_screen.dart`, so this rebuilds the
/// same chrome rather than reaching into another screen's private widget.
Future<void> _showShopTheLookSheet(BuildContext context, Reel reel) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop the look',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeXl,
                    height: AppTypography.lineHeightBase,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    color: AppColors.neutral1100,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const AppIcon(
                    AppIconGlyph.close,
                    size: 24,
                    color: AppColors.neutral1100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Consumer(
              builder: (context, ref, child) {
                final productsAsync = ref.watch(productsProvider);
                return productsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text(
                      "Couldn't load products.",
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                  data: (products) {
                    final tagged = products
                        .where((p) => reel.productIds.contains(p.id))
                        .toList();
                    if (tagged.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          'No products tagged in this reel.',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyBody,
                            fontSize: AppTypography.sizeSm,
                            color: AppColors.neutral600,
                          ),
                        ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final product in tagged)
                          _TaggedProductTile(
                            product: product,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.push('/product/${product.id}');
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _TaggedProductTile extends StatelessWidget {
  const _TaggedProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  static const double _imageSize = 56;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: _imageSize,
                height: _imageSize,
                child: product.imageUrl == null
                    ? const ColoredBox(color: AppColors.blackAlpha10)
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral1100,
                    ),
                  ),
                  Text(
                    product.priceLabel,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.neutral500,
            ),
          ],
        ),
      ),
    );
  }
}
