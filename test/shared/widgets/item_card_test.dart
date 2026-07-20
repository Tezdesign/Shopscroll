import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/item_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders title, price and store name', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ItemCard(
          title: "Bershka Menswear SS25: who's slaying better",
          price: r'$40',
          storeName: 'Bershka',
        ),
      ),
    );

    expect(
      find.text("Bershka Menswear SS25: who's slaying better"),
      findsOneWidget,
    );
    expect(find.text(r'$40'), findsOneWidget);
    expect(find.text('Bershka'), findsOneWidget);
  });

  testWidgets('hides the store row when storeName is null', (tester) async {
    await tester.pumpWidget(
      wrap(const ItemCard(title: 'Item', price: r'$10')),
    );

    expect(find.text('Bershka'), findsNothing);
  });

  testWidgets('shows a quantity stepper by default and invokes callbacks', (
    tester,
  ) async {
    var incremented = false;
    var decremented = false;
    var deleted = false;
    await tester.pumpWidget(
      wrap(
        ItemCard(
          title: 'Item',
          price: r'$10',
          quantity: 1,
          onIncrement: () => incremented = true,
          onDecrement: () => decremented = true,
          onDelete: () => deleted = true,
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.tap(find.text('-'));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(incremented, isTrue);
    expect(decremented, isTrue);
    expect(deleted, isTrue);
  });

  testWidgets('saved trailing shows a filled bookmark icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ItemCard(
          title: 'Item',
          price: r'$10',
          trailing: ItemCardTrailing.saved,
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('+'), findsNothing);
  });

  testWidgets('none trailing renders no trailing action', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ItemCard(
          title: 'Item',
          price: r'$10',
          trailing: ItemCardTrailing.none,
        ),
      ),
    );

    expect(find.text('+'), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
  });
}
