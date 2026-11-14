import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/seller_bottom_nav_bar.dart';

Widget _bar(SellerTabItem current, ValueChanged<SellerTabItem> onTap) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: SellerBottomNavBar(
          currentItem: current,
          onItemSelected: onTap,
        ),
      ),
    );

void main() {
  testWidgets('shows the five seller tabs and no buyer tabs', (tester) async {
    await tester.pumpWidget(_bar(SellerTabItem.home, (_) {}));

    for (final label in [
      'Home',
      'Products',
      'Activity',
      'Messages',
      'Profile',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Discover'), findsNothing);
    expect(find.text('Reels'), findsNothing);
  });

  testWidgets('tapping a tab reports it, and each tab is 44 or taller', (
    tester,
  ) async {
    SellerTabItem? tapped;
    await tester.pumpWidget(_bar(SellerTabItem.home, (item) => tapped = item));

    expect(
      tester.getSize(find.text('Products').hitTestable()).height,
      greaterThan(0),
    );
    final tab = find.ancestor(
      of: find.text('Messages'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(tab).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(tab).width, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Messages'));
    expect(tapped, SellerTabItem.messages);
  });

  testWidgets(
    'the active tab is highlighted and labelled, the top border is neutral300',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_bar(SellerTabItem.activity, (_) {}));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Activity')).label,
        'Activity',
      );
      Color colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      expect(colorOf('Activity'), AppColors.primary400);
      expect(colorOf('Home'), AppColors.neutral600);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SellerBottomNavBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, AppColors.neutral300);
      handle.dispose();
    },
  );

  testWidgets('a badged Messages tab shows a dot, the others do not', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: SellerBottomNavBar(
            currentItem: SellerTabItem.home,
            onItemSelected: (_) {},
            badged: const {SellerTabItem.messages},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tab-badge-messages')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-badge-activity')), findsNothing);
  });
}
