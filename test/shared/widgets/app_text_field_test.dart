import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_text_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
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
}
