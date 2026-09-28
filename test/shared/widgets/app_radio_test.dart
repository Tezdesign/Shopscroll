import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_radio.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(AppRadio),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('unselected is a 16 circle with the primary100 outline', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppRadio(selected: false)));

    expect(tester.getSize(find.byType(AppRadio)), const Size(16, 16));
    final border = decoration(tester).border! as Border;
    expect(border.top.color, AppColors.primary100);
  });

  testWidgets('selected turns the outline primary400 and adds a dot', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppRadio(selected: true)));

    final border = decoration(tester).border! as Border;
    expect(border.top.color, AppColors.primary400);
    // The dot is half the size of the circle.
    expect(
      find.descendant(
        of: find.byType(AppRadio),
        matching: find.byType(Container),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('size and outline colour can be set', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppRadio(
          selected: false,
          size: 12,
          outlineColor: AppColors.neutral1100,
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppRadio)), const Size(12, 12));
    final border = decoration(tester).border! as Border;
    expect(border.top.color, AppColors.neutral1100);
  });
}
