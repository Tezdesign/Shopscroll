import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_bottom_nav_bar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders all five tab labels', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppBottomNavBar(currentItem: AppTabItem.home, onItemSelected: (_) {}),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('shows a filled icon for the active tab and outline for others', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppBottomNavBar(
          currentItem: AppTabItem.profile,
          onItemSelected: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
  });

  testWidgets('invokes onItemSelected with the tapped tab', (tester) async {
    AppTabItem? selected;
    await tester.pumpWidget(
      wrap(
        AppBottomNavBar(
          currentItem: AppTabItem.home,
          onItemSelected: (item) => selected = item,
        ),
      ),
    );

    await tester.tap(find.text('Reels'));
    await tester.pump();

    expect(selected, AppTabItem.reels);
  });

  testWidgets('seller variant uses a different border color than user', (
    tester,
  ) async {
    Border borderOf(WidgetTester t) {
      final container = t.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      return decoration.border! as Border;
    }

    await tester.pumpWidget(
      wrap(
        AppBottomNavBar(
          currentItem: AppTabItem.home,
          onItemSelected: (_) {},
          variant: AppTabBarVariant.user,
        ),
      ),
    );
    final userBorder = borderOf(tester);

    await tester.pumpWidget(
      wrap(
        AppBottomNavBar(
          currentItem: AppTabItem.home,
          onItemSelected: (_) {},
          variant: AppTabBarVariant.seller,
        ),
      ),
    );
    final sellerBorder = borderOf(tester);

    expect(userBorder.top.color, AppColors.neutral200);
    expect(sellerBorder.top.color, AppColors.neutral300);
  });
}
