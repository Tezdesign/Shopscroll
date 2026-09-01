import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/phone_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the default hint text and static +1 prefix', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PhoneField()));

    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('renders a custom hint text', (tester) async {
    await tester.pumpWidget(
      wrap(const PhoneField(hintText: 'Phone number')),
    );

    expect(find.text('Phone number'), findsOneWidget);
  });

  testWidgets('typing updates the controller and fires onChanged', (
    tester,
  ) async {
    final controller = TextEditingController();
    var lastValue = '';
    await tester.pumpWidget(
      wrap(
        PhoneField(
          controller: controller,
          onChanged: (value) => lastValue = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '5551234567');

    expect(controller.text, '5551234567');
    expect(lastValue, '5551234567');
  });

  testWidgets('renders no helper line when helperText is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PhoneField()));

    expect(
      find.text('We will use this number to validate your account.'),
      findsNothing,
    );
  });

  testWidgets('renders the given helper text', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PhoneField(
          helperText: 'We will use this number to validate your account.',
        ),
      ),
    );

    expect(
      find.text('We will use this number to validate your account.'),
      findsOneWidget,
    );
  });

  testWidgets('disables the input when enabled is false', (tester) async {
    await tester.pumpWidget(wrap(const PhoneField(enabled: false)));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });
}
