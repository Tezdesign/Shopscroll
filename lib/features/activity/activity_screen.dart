import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/segmented_tabs.dart';
import 'collection_tab.dart';
import 'messages_tab.dart';
import 'purchases_tab.dart';

/// Reproduces the Figma Activity frames (Purchases 291:2537, My collection
/// 292:8980 and 309:2196, Messages 826:4960, file `toOakybJ0DaJmU7vcEC0AW`);
/// the build spec and acceptance criteria are in
/// `docs/specs/0008-activity-screens/index.md`. Opened at `/activity`, the
/// Activity tab of the bottom bar.
///
/// One search field filters whichever tab is open, and its text stays when
/// the tab changes (AC-2). The open tab is widget state, so tapping a tab
/// swaps the body in place and the route does not change (AC-1).
///
/// Deviations from the frames (spec 0008): the search hint reads "Search
/// for anything" on every tab, totals read `$320`, the device status bar is
/// not built, and loading, error, empty, Undo and failure states are not
/// drawn in the frames and follow the app's existing patterns.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _tabs = ['Purchases', 'My collection', 'Messages'];

  final _search = TextEditingController();
  int _tab = 0;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: SearchField(
                  controller: _search,
                  onChanged: (text) => setState(() => _query = text),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: SegmentedTabs(
                labels: _tabs,
                activeIndex: _tab,
                onChanged: (index) => setState(() => _tab = index),
                distribution: SegmentedTabsDistribution.spaceBetween,
                fontSize: AppTypography.sizeBase,
                bottomPadding: AppSpacing.xs,
                inactiveColor: AppColors.neutral500,
                tapHeight: 44,
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => PurchasesTab(query: _query),
                1 => CollectionTab(query: _query),
                _ => MessagesTab(query: _query),
              },
            ),
          ],
        ),
      ),
    );
  }
}
