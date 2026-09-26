import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/features/catalog/product_detail_screen.dart';
import 'package:marketplace_app/shared/widgets/add_to_cart_toggle.dart';

void main() {
  // Recommended product cards below also carry "Add to cart" pills.
  Finder toggleText(String text) => find.descendant(
    of: find.byType(AddToCartToggle),
    matching: find.text(text),
  );

  Future<void> open(WidgetTester tester, String productId) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProductDetailScreen(productId: productId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump(mockNetworkDelay);
  }

  testWidgets(
    'Add to cart saves the line and then shows its added state (AC-10)',
    (tester) async {
      // Not in the seed cart, so it starts as "Add to cart".
      final product = mockProducts[3];
      await open(tester, product.id);

      expect(toggleText('Add to cart'), findsOneWidget);
      await tester.tap(toggleText('Add to cart'));
      await tester.pump();

      expect(toggleText('Added to cart'), findsOneWidget);
      await tester.pump(mockNetworkDelay);
    },
  );
}
