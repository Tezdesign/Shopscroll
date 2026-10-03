import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_seller/main.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

void main() {
  testWidgets('starts with the shared theme and the placeholder screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SellerApp());

    expect(find.text('Seller app coming soon'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, AppTheme.light);
  });
}
