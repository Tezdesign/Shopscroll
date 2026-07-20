import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/product_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders title, price and store name', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProductCard(
          title: "Bershka Menswear SS25: who's slaying better",
          price: r'$40',
          storeName: 'Apple',
        ),
      ),
    );

    expect(find.text("Bershka Menswear SS25: who's slaying better"), findsOneWidget);
    expect(find.text(r'$40'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Add to cart'), findsOneWidget);
  });

  testWidgets('hides the add-to-cart button when showAddToCart is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProductCard(
          title: 'No button product',
          price: r'$10',
          storeName: 'Store',
          showAddToCart: false,
        ),
      ),
    );

    expect(find.text('Add to cart'), findsNothing);
  });

  testWidgets('renders color swatches when provided', (tester) async {
    await tester.pumpWidget(
      wrap(
        ProductCard(
          title: 'Colorful product',
          price: r'$25',
          storeName: 'Store',
          colorOptions: const [
            AppColors.neutral100,
            AppColors.primary400,
            AppColors.secondary400,
          ],
        ),
      ),
    );

    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('medium size lays out at the compact width', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProductCard(
          title: 'Compact product',
          price: r'$5',
          storeName: 'Store',
          size: ProductCardSize.medium,
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find.byType(SizedBox).first,
    );
    expect(sizedBox.width, 135);
  });

  testWidgets('invokes onAddToCart when the button is tapped', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ProductCard(
          title: 'Tappable product',
          price: r'$15',
          storeName: 'Store',
          onAddToCart: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Add to cart'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
