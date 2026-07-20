import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_button.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the label', (tester) async {
    await tester.pumpWidget(wrap(const AppButton(label: 'Back')));

    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('big variants lay out at the fixed width', (tester) async {
    await tester.pumpWidget(
      wrap(const AppButton(label: 'Back', size: AppButtonSize.big)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, 274);
  });

  testWidgets('small variants do not have a fixed width', (tester) async {
    await tester.pumpWidget(
      wrap(const AppButton(label: 'Back', size: AppButtonSize.small)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, isNull);
  });

  testWidgets('invokes onPressed when enabled and tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AppButton(label: 'Back', onPressed: () => tapped = true)),
    );

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not invoke onPressed when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppButton(
          label: 'Back',
          enabled: false,
          onPressed: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('renders leading and trailing icons when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const AppButton(
          label: 'Continue',
          leadingIcon: Icons.arrow_back,
          trailingIcon: Icons.arrow_forward,
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('secondary variant renders with a transparent background', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const AppButton(label: 'Back', variant: AppButtonVariant.secondary),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.border, isNotNull);
  });
}
