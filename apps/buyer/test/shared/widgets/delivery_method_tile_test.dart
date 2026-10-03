import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/delivery_method_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  Color borderColor(WidgetTester tester) =>
      ((tester
                          .widget<Container>(
                            find
                                .descendant(
                                  of: find.byType(DeliveryMethodTile),
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .color;

  testWidgets('shows the title and the price, and reports taps (AC-7)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        DeliveryMethodTile(
          title: 'Standard Delivery',
          priceLabel: r'$10',
          selected: false,
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Standard Delivery'), findsOneWidget);
    expect(find.text(r'$10'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DeliveryMethodTile)).height,
      greaterThanOrEqualTo(52),
    );
    await tester.tap(find.byType(DeliveryMethodTile));
    expect(taps, 1);
  });

  testWidgets('selected turns the border primary400', (tester) async {
    await tester.pumpWidget(
      wrap(
        DeliveryMethodTile(
          title: 'Standard Delivery',
          priceLabel: r'$10',
          selected: false,
          onTap: () {},
        ),
      ),
    );
    expect(borderColor(tester), AppColors.neutral400);

    await tester.pumpWidget(
      wrap(
        DeliveryMethodTile(
          title: 'Standard Delivery',
          priceLabel: r'$10',
          selected: true,
          onTap: () {},
        ),
      ),
    );
    expect(borderColor(tester), AppColors.primary400);
  });

  testWidgets('announces its title, price and selected state (AC-23)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        DeliveryMethodTile(
          title: 'Standard Delivery',
          priceLabel: r'$10',
          selected: true,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(DeliveryMethodTile)),
      matchesSemantics(
        label: r'Standard Delivery, $10',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });
}
