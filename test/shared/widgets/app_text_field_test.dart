import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_text_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the given hint text', (tester) async {
    await tester.pumpWidget(
      wrap(const AppTextField(hintText: 'Enter your name')),
    );

    expect(find.text('Enter your name'), findsOneWidget);
  });

  testWidgets('typing updates the controller and fires onChanged', (
    tester,
  ) async {
    final controller = TextEditingController();
    var lastValue = '';
    await tester.pumpWidget(
      wrap(
        AppTextField(
          controller: controller,
          onChanged: (value) => lastValue = value,
        ),
      ),
    );

    await tester.enterText(find.byType(AppTextField), 'Jane');

    expect(controller.text, 'Jane');
    expect(lastValue, 'Jane');
  });

  testWidgets('renders helperText below the field', (tester) async {
    await tester.pumpWidget(
      wrap(const AppTextField(helperText: 'This is public')),
    );

    expect(find.text('This is public'), findsOneWidget);
  });

  testWidgets('renders errorText below the field', (tester) async {
    await tester.pumpWidget(
      wrap(const AppTextField(errorText: 'This username is taken')),
    );

    expect(find.text('This username is taken'), findsOneWidget);
  });

  testWidgets('runs the validator through an ancestor Form', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      wrap(
        Form(
          key: formKey,
          child: AppTextField(
            validator: (value) =>
                (value == null || value.isEmpty) ? "Can't be empty" : null,
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text("Can't be empty"), findsOneWidget);
  });

  testWidgets('disables editing when enabled is false', (tester) async {
    await tester.pumpWidget(wrap(const AppTextField(enabled: false)));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
  });

  // The four Figma states (component set node 5290:7177): Default, filling,
  // Filled, error.
  TextField innerField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  testWidgets('decoration carries the Figma border colors per state', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppTextField()));

    final decoration = innerField(tester).decoration!;
    expect(
      (decoration.border! as OutlineInputBorder).borderSide.color,
      AppColors.neutral500,
    );
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      AppColors.neutral500,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AppColors.primary500,
    );
    expect(
      (decoration.errorBorder! as OutlineInputBorder).borderSide.color,
      AppColors.error500,
    );
    expect(
      (decoration.focusedErrorBorder! as OutlineInputBorder).borderSide.color,
      AppColors.error500,
    );
  });

  testWidgets('Default and Filled: black text; filling: blue text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: const [
            AppTextField(),
            TextField(key: Key('other')),
          ],
        ),
      ),
    );

    TextField first() => tester.widget<TextField>(find.byType(TextField).first);

    expect(first().style!.color, AppColors.neutral1100);

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Test');
    await tester.pump();
    expect(first().style!.color, AppColors.primary500);

    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(first().style!.color, AppColors.neutral1100);
  });

  testWidgets('error: red message in Plus Jakarta Sans, text stays black '
      'even while focused', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppTextField(errorText: 'Please enter a valid email address.'),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(innerField(tester).style!.color, AppColors.neutral1100);
    final message = tester.widget<Text>(
      find.text('Please enter a valid email address.'),
    );
    expect(message.style!.color, AppColors.error500);
    expect(message.style!.fontFamily, AppTypography.fontFamilyDisplay);
  });

  testWidgets('a validator error also turns the text black while focused', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      wrap(
        Form(
          key: formKey,
          child: AppTextField(
            validator: (value) =>
                (value == null || value.isEmpty) ? "Can't be empty" : null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(innerField(tester).style!.color, AppColors.primary500);

    formKey.currentState!.validate();
    await tester.pump();
    await tester.pump();

    expect(find.text("Can't be empty"), findsOneWidget);
    expect(innerField(tester).style!.color, AppColors.neutral1100);
  });

  testWidgets(
    'geometry matches Figma: message flush left, 4px under a 48px box',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppTextField(
              errorText: 'Please enter a valid email address.',
            ),
          ),
        ),
      );

      final box = tester.getRect(find.byType(TextFormField));
      final message = tester.getRect(
        find.text('Please enter a valid email address.'),
      );

      expect(box.height, closeTo(48, 1)); // 17.5px line rounds up to 18
      expect(message.left, box.left);
      expect(message.top - box.bottom, 4);
    },
  );
}
