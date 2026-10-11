import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/shared/widgets/area_switch.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

Future<List<bool>> pumpSwitch(
  WidgetTester tester, {
  required bool sellerSelected,
}) async {
  final taps = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: AreaSwitch(sellerSelected: sellerSelected, onChanged: taps.add),
        ),
      ),
    ),
  );
  return taps;
}

Color? halfFill(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('the selected half is white, the other has no fill', (
    tester,
  ) async {
    await pumpSwitch(tester, sellerSelected: true);
    expect(halfFill(tester, 'Seller'), AppColors.neutral100);
    expect(halfFill(tester, 'Buyer'), Colors.transparent);

    await pumpSwitch(tester, sellerSelected: false);
    expect(halfFill(tester, 'Buyer'), AppColors.neutral100);
    expect(halfFill(tester, 'Seller'), Colors.transparent);
  });

  testWidgets('tapping a half reports the side: true for Seller', (
    tester,
  ) async {
    final taps = await pumpSwitch(tester, sellerSelected: false);

    await tester.tap(find.text('Seller'));
    await tester.tap(find.text('Buyer'));

    expect(taps, [true, false]);
  });

  testWidgets('it hugs its labels, a compact pill and not a full width bar', (
    tester,
  ) async {
    await pumpSwitch(tester, sellerSelected: false);

    // The test font is wider than Inter, so compare with the 800 px surface
    // instead of the 149 px of the design.
    expect(tester.getSize(find.byType(AreaSwitch)).width, lessThan(400));
  });
}
