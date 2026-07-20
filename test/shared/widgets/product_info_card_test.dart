import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/product_info_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders store name and description', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProductInfoCard(
          storeName: 'Bershka',
          description: "Bershka Menswear SS25: who's slaying better",
        ),
      ),
    );

    expect(find.text('Bershka'), findsOneWidget);
    expect(
      find.text("Bershka Menswear SS25: who's slaying better"),
      findsOneWidget,
    );
  });

  testWidgets('does not render a price or add-to-cart button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProductInfoCard(storeName: 'Pull&bear', description: 'Item'),
      ),
    );

    expect(find.text('Add to cart'), findsNothing);
  });

  testWidgets('lays out at the fixed card width', (tester) async {
    await tester.pumpWidget(
      wrap(const ProductInfoCard(storeName: 'Store', description: 'Desc')),
    );

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, 110.625);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ProductInfoCard(
          storeName: 'Store',
          description: 'Desc',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(ProductInfoCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
