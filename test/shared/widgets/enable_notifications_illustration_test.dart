import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/enable_notifications_illustration.dart';

void main() {
  testWidgets('renders the bell illustration at the requested size',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: EnableNotificationsIllustration(size: 200),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
