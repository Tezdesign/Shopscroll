import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

/// One tile on [InterestsScreen]: a shopping category the buyer can say they
/// care about, drawn as the Figma frame's "Prodcut view" card.
///
/// [tint], [labelColor] and [image] are per card artwork, not theme values:
/// the source frame paints each card with a raw fill and a photo of its own,
/// none of which exist in the Figma variable collection the design tokens
/// come from (root `AGENTS.md`). They are named here, beside the category
/// they belong to, rather than invented as tokens in `app_theme.dart`.
class Interest {
  const Interest({
    required this.category,
    required this.example,
    required this.tint,
    required this.labelColor,
    required this.image,
  });

  /// The category itself, and what selecting this tile means. Shown small
  /// above [example].
  final String category;

  /// The product the card's photo shows, e.g. "SOFA" for Home & Living. It
  /// illustrates the category rather than being separately selectable.
  final String example;

  /// The card's background fill.
  final Color tint;

  /// The [category] label's color, which differs per card in the frame.
  final Color labelColor;
  final String image;

  @override
  bool operator ==(Object other) =>
      other is Interest && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

/// The categories [InterestsScreen] offers.
///
/// The source frame shows eleven cards, but only four distinct categories:
/// most are the same placeholder card repeated to fill the grid. Each
/// category is listed once here, with the photo and fill from the card that
/// introduced it. Two of the repeats carry their own photo and fill under a
/// wrong label ("Toys & Entertainment" on a framed painting, and on party
/// decorations), so they are kept as categories of their own under the names
/// they look like: a real taxonomy has to come from the catalog.
const interests = <Interest>[
  Interest(
    category: 'Home & Living',
    example: 'SOFA',
    tint: Color(0xFFEEEEEE),
    labelColor: Color(0xFF444444),
    image: 'assets/interests/sofa.png',
  ),
  Interest(
    category: 'Clothing & Shoes',
    example: 'SNEAKERS',
    // The frame paints this one rgb(39, 163, 218) at 20% over white; that is
    // flattened here, since the card below it is opaque anyway.
    tint: Color(0xFFD5EDF8),
    labelColor: Color(0xFF0A73A1),
    image: 'assets/interests/sneakers.png',
  ),
  Interest(
    category: 'Toys & Entertainment',
    example: 'TOY TRAIN',
    tint: Color(0xFFFEF9C4),
    labelColor: Color(0xFFD4B100),
    image: 'assets/interests/toy_train.png',
  ),
  Interest(
    category: 'Art & Collectibles',
    example: 'PAINTING',
    tint: Color(0xFFF2E7E3),
    labelColor: Color(0xFFB18531),
    image: 'assets/interests/painting.png',
  ),
  Interest(
    category: 'Party & Decor',
    example: 'PARTY DECORS',
    tint: Color(0xFFE3F2E6),
    labelColor: Color(0xFF25D02C),
    image: 'assets/interests/party_decor.png',
  ),
  Interest(
    category: 'Jewelry & Accessories',
    example: 'DIAMOND RING',
    tint: Color(0xFFFAE8E8),
    labelColor: Color(0xFFC63D42),
    image: 'assets/interests/diamond_ring.png',
  ),
];

/// Reproduces the Figma "Set up Your profile" screen (node 5288:9912), the
/// step after a verified phone number or email address in the redesigned sign
/// up flow — see `lib/features/onboarding/AGENTS.md`.
///
/// A heading, a grid of category cards that toggle on tap (a selected card
/// gets a [AppColors.success500] border, as in the frame), and "Let's start"
/// at the bottom. Like the other screens here it navigates nowhere itself:
/// [onStart] reports the chosen categories and [app_router.dart] decides what
/// follows.
///
/// Deviations from the source frame:
/// - The frame's cards are a design system component shrunk to about a third
///   of its size, so its text lands at 6.25px and 13.75px. Both are scaled up
///   to the nearest readable tokens ([AppTypography.labelMedium] and
///   [AppTypography.headlineSmall]); reproducing the literal sizes would be
///   unreadable on a device.
/// - Each card also carries an invisible "SHOP NOW" button (opacity 0, and
///   1.37px text) left over from the component it was built from. It is not
///   reproduced.
/// - The nav bar's trailing icon (node 5288:9931) is drawn at opacity 0 and
///   is the same chevron as the back arrow, so it is a placeholder rather
///   than an action, and is left out.
/// - Two cards sit on a drawn ellipse shadow under the photo and the rest do
///   not. The shadow is dropped, so every card matches.
/// - Selecting nothing still lets "Let's start" through: the frame shows no
///   disabled state for it, and nothing downstream needs a choice yet.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key, required this.onStart, this.onBack});

  /// Called with the chosen categories, in the order they are listed, when
  /// "Let's start" is tapped. Empty when nothing is selected.
  final void Function(List<Interest> selected) onStart;

  /// The nav bar's back arrow. Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final _selected = <Interest>{};

  /// Three across, as the frame lays them out.
  static const int _columns = 3;

  /// The frame's cards are 107.813 x 121.875.
  static const double _cardAspectRatio = 107.813 / 121.875;

  void _toggle(Interest interest) {
    setState(() {
      if (!_selected.remove(interest)) _selected.add(interest);
    });
  }

  void _start() {
    widget.onStart(interests.where(_selected.contains).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text('Set up Your profile', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Text(
                'What are you interest in the most?',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
            ),
            // The frame spaces the grid 32 from the heading; the scale stops
            // at 24, so this is the base step twice over.
            const SizedBox(height: AppSpacing.base * 2),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.base,
                  childAspectRatio: _cardAspectRatio,
                ),
                itemCount: interests.length,
                itemBuilder: (context, index) {
                  final interest = interests[index];
                  return _InterestCard(
                    interest: interest,
                    selected: _selected.contains(interest),
                    onTap: () => _toggle(interest),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(label: "Let's start", onPressed: _start),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card in [InterestsScreen]'s grid (the frame's "Prodcut view"
/// instances): the category above the product the photo shows, with the
/// photo itself anchored bottom right.
class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  /// The frame's selected cards carry a 2px border.
  static const double _selectedBorderWidth = 2;

  /// How much of the card the photo covers, from the frame's own cards.
  static const double _photoWidthFactor = 0.74;
  static const double _photoHeightFactor = 0.6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: interest.category,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: interest.tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(
                    color: AppColors.success500,
                    width: _selectedBorderWidth,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomRight,
                  child: FractionallySizedBox(
                    widthFactor: _photoWidthFactor,
                    heightFactor: _photoHeightFactor,
                    child: Image.asset(
                      interest.image,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        interest.category,
                        style: AppTypography.labelMedium.copyWith(
                          color: interest.labelColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        interest.example,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.neutral800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
