import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/checkout_sheet.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  Future<void> open(
    WidgetTester tester, {
    required void Function(String?) got,
  }) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => got(
              await showCheckoutSheet<String>(
                context,
                title: 'Contact information',
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).pop('done'),
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows the title and the child, and returns what the child pops',
    (tester) async {
      String? result;
      await open(tester, got: (value) => result = value);

      expect(find.text('Contact information'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(result, 'done');
      expect(find.text('Contact information'), findsNothing);
    },
  );

  testWidgets('the close button closes with null and has a 44 tap area', (
    tester,
  ) async {
    String? result = 'unset';
    await open(tester, got: (value) => result = value);

    final close = find.bySemanticsLabel('Close');
    expect(tester.getSize(close).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('the title is announced as a header', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, got: (_) {});

    expect(
      tester.getSemantics(find.text('Contact information')),
      matchesSemantics(label: 'Contact information', isHeader: true),
    );
    handle.dispose();
  });
}
