import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/category_chip.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the label', (tester) async {
    await tester.pumpWidget(wrap(const CategoryChip(label: 'Deals')));

    expect(find.text('Deals'), findsOneWidget);
  });

  testWidgets('renders the icon once when provided', (tester) async {
    await tester.pumpWidget(
      wrap(const CategoryChip(label: 'Deals', icon: Icons.local_offer)),
    );

    expect(find.byIcon(Icons.local_offer), findsOneWidget);
  });

  testWidgets('unselected uses a white background with a black border', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const CategoryChip(label: 'Deals')));

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.neutral100);
    expect(decoration.border, isNotNull);
  });

  testWidgets('selected uses a filled primary background with no border', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const CategoryChip(label: 'Deals', selected: true)),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primary400);
    expect(decoration.border, isNull);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(CategoryChip(label: 'Deals', onTap: () => tapped = true)),
    );

    await tester.tap(find.text('Deals'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
