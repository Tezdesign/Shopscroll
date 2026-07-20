import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/reel.dart';
import '../../data/providers/reel_providers.dart';
import '../../shared/widgets/reel_card.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/segmented_tabs.dart';

/// Reproduces the Figma "Reels" screen ("The design - user" page, node
/// 234:646): a search field, a "For you" / "Following" tab row, and a two
/// column grid of [ReelCard]s. Full build spec and acceptance criteria:
/// `docs/specs/0002-reels-screen.md`.
///
/// "Following" has no data behind it anywhere in this app (no follow/social
/// graph model exists, see spec 0002); it renders as a permanently inactive
/// tab rather than a real filter, a deliberate deferral, not an oversight.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  static const _tabs = ['For you', 'Following'];

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Reel> _applySearch(List<Reel> reels) {
    if (_searchQuery.isEmpty) return reels;
    return reels
        .where(
          (r) =>
              r.caption.toLowerCase().contains(_searchQuery) ||
              r.storeName.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(reelsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: SearchField(
                controller: _searchController,
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: SegmentedTabs(
                labels: _tabs,
                activeIndex: 0,
                // "Following" is a permanently inert tap target; see class
                // doc. "For you" is already active, so there's nothing to
                // change on tap either.
                onChanged: (_) {},
                distribution: SegmentedTabsDistribution.spaceBetween,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: reelsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const _CenteredMessage(
                  text: "Couldn't load reels.",
                ),
                data: (allReels) {
                  final reels = _applySearch(allReels);
                  if (reels.isEmpty) {
                    return _CenteredMessage(
                      text: _searchQuery.isNotEmpty
                          ? 'No reels match your search.'
                          : 'No reels yet.',
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      0,
                      AppSpacing.base,
                      AppSpacing.xl,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.base,
                      runSpacing: AppSpacing.base,
                      children: [
                        for (final reel in reels)
                          ReelCard(
                            reel: reel,
                            onTap: () => context.push(
                              '/reels/${reel.id}',
                              extra: [for (final r in reels) r.id],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
            color: AppColors.neutral600,
          ),
        ),
      ),
    );
  }
}
