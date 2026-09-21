import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/country_dial_code.dart';
import 'package:marketplace_app/shared/widgets/phone_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the default hint text and +1 prefix', (tester) async {
    await tester.pumpWidget(wrap(const PhoneField()));

    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('renders the country it is given', (tester) async {
    await tester.pumpWidget(
      wrap(const PhoneField(country: CountryDialCode('TN', '+216', 'Tunisia'))),
    );

    expect(find.text('+216'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
  });

  testWidgets('tapping the prefix picks a country from the sheet', (
    tester,
  ) async {
    CountryDialCode? picked;
    await tester.pumpWidget(
      wrap(PhoneField(onCountryChanged: (country) => picked = country)),
    );

    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'Tunisia');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tunisia'));
    await tester.pumpAndSettle();

    expect(picked?.dialCode, '+216');
  });

  testWidgets('the prefix is inert while the field is disabled', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      wrap(PhoneField(enabled: false, onCountryChanged: (_) => changes++)),
    );

    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    expect(find.text('Country'), findsNothing);
    expect(changes, 0);
  });

  testWidgets('renders a custom hint text', (tester) async {
    await tester.pumpWidget(wrap(const PhoneField(hintText: 'Phone number')));

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

  testWidgets('renders no helper line when helperText is null', (tester) async {
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

  testWidgets('renders errorText in place of helperText', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PhoneField(
          helperText: 'We will use this number to validate your account.',
          errorText: 'Please enter a valid phone number.',
        ),
      ),
    );

    expect(find.text('Please enter a valid phone number.'), findsOneWidget);
    expect(
      find.text('We will use this number to validate your account.'),
      findsNothing,
    );
  });

  // The four Figma states (component set node 5290:7177): Default, filling,
  // Filled, error — border, typed text and "+1" colors.
  Color borderColor(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    return (decoration.border! as Border).top.color;
  }

  Color textColor(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).style!.color!;

  Color prefixColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('+1')).style!.color!;

  testWidgets('Default: grey border, black +1', (tester) async {
    await tester.pumpWidget(wrap(const PhoneField()));

    expect(borderColor(tester), AppColors.neutral500);
    expect(prefixColor(tester), AppColors.neutral1100);
  });

  testWidgets('filling: blue border and blue text, +1 stays black', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PhoneField()));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '123 431 142');
    await tester.pump();

    expect(borderColor(tester), AppColors.primary500);
    expect(textColor(tester), AppColors.primary500);
    expect(prefixColor(tester), AppColors.neutral1100);
  });

  testWidgets('Filled: grey border, black text, grey +1', (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            const PhoneField(),
            // Something else to take focus, so the field above is unfocused.
            const TextField(key: Key('other')),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '123 431 142');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(borderColor(tester), AppColors.neutral500);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).style!.color,
      AppColors.neutral1100,
    );
    expect(prefixColor(tester), AppColors.neutral500);
  });

  testWidgets('error: red border, black text, grey +1, red message', (
    tester,
  ) async {
    final controller = TextEditingController(text: '123 431 142');
    await tester.pumpWidget(
      wrap(
        PhoneField(
          controller: controller,
          errorText: 'Please enter a valid phone number.',
        ),
      ),
    );

    // Even focused, error wins over the blue filling look.
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(borderColor(tester), AppColors.error500);
    expect(textColor(tester), AppColors.neutral1100);
    expect(prefixColor(tester), AppColors.neutral500);

    final message = tester.widget<Text>(
      find.text('Please enter a valid phone number.'),
    );
    expect(message.style!.color, AppColors.error500);
    expect(message.style!.fontFamily, AppTypography.fontFamilyDisplay);
  });

  testWidgets('disabled: muted border, like a locked number', (tester) async {
    await tester.pumpWidget(wrap(const PhoneField(enabled: false)));

    expect(borderColor(tester), AppColors.neutral300);
  });
}
