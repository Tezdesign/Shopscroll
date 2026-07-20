import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/add_to_cart_toggle.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('shows "Add to cart" when not added', (tester) async {
    await tester.pumpWidget(wrap(const AddToCartToggle(added: false)));

    expect(find.text('Add to cart'), findsOneWidget);
  });

  testWidgets('shows "Added to cart" in success color when added', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AddToCartToggle(added: true)));

    final text = tester.widget<Text>(find.text('Added to cart'));
    expect(text.style?.color, AppColors.success400);
  });

  testWidgets('hides the label in iconOnly display', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AddToCartToggle(
          added: false,
          display: AddToCartDisplay.iconOnly,
        ),
      ),
    );

    expect(find.text('Add to cart'), findsNothing);
    expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AddToCartToggle(added: false, onTap: () => tapped = true)),
    );

    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
