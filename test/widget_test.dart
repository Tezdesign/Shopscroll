import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('App boots to the Home screen and loads mocked data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MarketplaceApp()));

    // Don't pumpAndSettle: the loading spinners animate indefinitely and
    // banner images hit the network, neither of which ever "settles" in a
    // test environment. Instead pump past the mock providers' artificial
    // 300ms delay so their data resolves.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Shopscroll'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    // "You may also like" sits below the fold — scroll it into view.
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pump();

    expect(find.text('You may also like'), findsOneWidget);
  });
}
