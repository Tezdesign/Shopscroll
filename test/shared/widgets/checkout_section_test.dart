import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/checkout_section.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  Border border(WidgetTester tester) =>
      (tester
                      .widget<Container>(
                        find.descendant(
                          of: find.byType(CheckoutSection),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .border!
          as Border;

  group('CheckoutSection', () {
    testWidgets('shows its title and child, with a border under it', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const CheckoutSection(title: 'Delivery', child: Text('body'))),
      );

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(border(tester).bottom.color, AppColors.neutral200);
      expect(border(tester).top, BorderSide.none);
    });

    testWidgets('topBorder moves the border to the top', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CheckoutSection(
            title: 'Order Summary',
            topBorder: true,
            child: SizedBox(),
          ),
        ),
      );

      expect(border(tester).top.color, AppColors.neutral200);
      expect(border(tester).bottom, BorderSide.none);
    });

    testWidgets('the title is announced as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const CheckoutSection(title: 'Delivery', child: SizedBox())),
      );

      expect(
        tester.getSemantics(find.text('Delivery')),
        matchesSemantics(label: 'Delivery', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('AddInfoRow', () {
    testWidgets('taps through, with a label and a 44 high tap area', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(AddInfoRow(label: 'Add your address', onTap: () => taps++)),
      );

      expect(find.text('Add your address'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AddInfoRow)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('Add your address'));
      expect(taps, 1);
    });

    testWidgets('is announced as a button with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(AddInfoRow(label: 'Add your address', onTap: () {})),
      );

      expect(find.bySemanticsLabel('Add your address'), findsOneWidget);
      handle.dispose();
    });
  });

  group('InfoSummaryRow', () {
    testWidgets('shows the bold line, the grey lines and a working pencil', (
      tester,
    ) async {
      var edits = 0;
      await tester.pumpWidget(
        wrap(
          InfoSummaryRow(
            title: 'Sara Ben Ali',
            lines: const ['sara@example.com', '+21650460604'],
            editLabel: 'Edit contact information',
            onEdit: () => edits++,
          ),
        ),
      );

      expect(find.text('Sara Ben Ali'), findsOneWidget);
      expect(find.text('sara@example.com'), findsOneWidget);
      expect(find.text('+21650460604'), findsOneWidget);

      final pencil = find.bySemanticsLabel('Edit contact information');
      expect(tester.getSize(pencil).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(pencil).height, greaterThanOrEqualTo(44));
      await tester.tap(pencil);
      expect(edits, 1);
    });
  });
}
