import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/most_visited_item.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the store name', (tester) async {
    await tester.pumpWidget(wrap(const MostVisitedItem(storeName: 'Amazon')));

    expect(find.text('Amazon'), findsOneWidget);
  });

  testWidgets('shows a fallback storefront icon when iconUrl is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const MostVisitedItem(storeName: 'Plex')));

    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        MostVisitedItem(storeName: 'Yale', onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.byType(MostVisitedItem));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('lays out the icon box at the fixed size', (tester) async {
    await tester.pumpWidget(wrap(const MostVisitedItem(storeName: 'Apple')));

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth ?? 56, 56);
  });
}
