import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/shared/widgets/shipping_items_section.dart';

void main() {
  CartItem line(String title, String store, double price, {int qty = 1}) {
    return CartItem(
      id: title,
      quantity: qty,
      addedAt: DateTime(2026, 7, 1),
      product: Product(
        id: title,
        title: title,
        description: '',
        price: price,
        category: 'Fashion',
        storeId: store,
        storeName: store,
        createdAt: DateTime(2026, 7, 1),
      ),
    );
  }

  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

  final watch = line('Apple watch serie 5', 'Bershka', 20, qty: 2);

  testWidgets('starts collapsed with only the title', (tester) async {
    await tester.pumpWidget(wrap(ShippingItemsSection(items: [watch])));

    expect(find.text('Shipping items'), findsOneWidget);
    expect(find.text('Bershka'), findsNothing);
    expect(find.text('Apple watch serie 5'), findsNothing);
  });

  testWidgets('tapping the header shows quantity, title and line total, '
      'tapping again hides them', (tester) async {
    await tester.pumpWidget(wrap(ShippingItemsSection(items: [watch])));

    await tester.tap(find.text('Shipping items'));
    await tester.pump();

    expect(find.text('Bershka'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Apple watch serie 5'), findsOneWidget);
    expect(find.text(r'$40'), findsOneWidget);

    await tester.tap(find.text('Shipping items'));
    await tester.pump();

    expect(find.text('Bershka'), findsNothing);
  });

  testWidgets('initiallyExpanded opens it and groups lines by store', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ShippingItemsSection(
          initiallyExpanded: true,
          items: [
            watch,
            line('Jacket', 'Nike', 90),
            line('Cap', 'Bershka', 10),
          ],
        ),
      ),
    );

    expect(find.text('Bershka'), findsOneWidget);
    expect(find.text('Nike'), findsOneWidget);
    expect(find.text('Jacket'), findsOneWidget);
    expect(find.text('Cap'), findsOneWidget);
  });

  testWidgets('the header is announced as an expandable button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(ShippingItemsSection(items: [watch])));

    expect(
      tester.getSemantics(find.text('Shipping items')),
      matchesSemantics(
        label: 'Shipping items',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
      ),
    );
    handle.dispose();
  });
}
