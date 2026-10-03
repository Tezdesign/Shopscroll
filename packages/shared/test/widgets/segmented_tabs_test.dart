import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/segmented_tabs.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders all labels', (tester) async {
    await tester.pumpWidget(
      wrap(
        SegmentedTabs(
          labels: const ['For you', 'Sports', 'Makeup'],
          activeIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
  });

  testWidgets('invokes onChanged with the tapped index', (tester) async {
    int? selected;
    await tester.pumpWidget(
      wrap(
        SegmentedTabs(
          labels: const ['Purchases', 'My collection', 'Messages'],
          activeIndex: 0,
          onChanged: (index) => selected = index,
          distribution: SegmentedTabsDistribution.spaceBetween,
        ),
      ),
    );

    await tester.tap(find.text('Messages'));
    await tester.pump();

    expect(selected, 2);
  });

  testWidgets('active tab is styled differently from inactive tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SegmentedTabs(
          labels: const ['Products', 'Reels'],
          activeIndex: 0,
          onChanged: (_) {},
          distribution: SegmentedTabsDistribution.equal,
        ),
      ),
    );

    final activeText = tester.widget<Text>(find.text('Products'));
    final inactiveText = tester.widget<Text>(find.text('Reels'));

    expect(activeText.style?.color, AppColors.neutral1100);
    expect(inactiveText.style?.color, AppColors.neutral600);
  });

  testWidgets('equal distribution wraps each tab in Expanded', (tester) async {
    await tester.pumpWidget(
      wrap(
        SegmentedTabs(
          labels: const ['Products', 'Reels'],
          activeIndex: 0,
          onChanged: (_) {},
          distribution: SegmentedTabsDistribution.equal,
        ),
      ),
    );

    expect(find.byType(Expanded), findsNWidgets(2));
  });

  testWidgets('tapHeight gives each tab at least that tall a tap area', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SegmentedTabs(
          labels: const ['Products', 'Reels'],
          activeIndex: 0,
          onChanged: (_) {},
          tapHeight: 44,
        ),
      ),
    );

    final tab = find.ancestor(
      of: find.text('Reels'),
      matching: find.byType(Container),
    );
    expect(tester.getSize(tab.first).height, greaterThanOrEqualTo(44));
  });
}
