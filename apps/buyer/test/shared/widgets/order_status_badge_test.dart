import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/order_status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the label for each status', (tester) async {
    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.delivered)),
    );
    expect(find.text('Delivered'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.inProgress)),
    );
    expect(find.text('In progress'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.canceled)),
    );
    expect(find.text('Canceled'), findsOneWidget);
  });

  testWidgets('uses distinct colors per status', (tester) async {
    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.canceled)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.error100);
  });

  testWidgets('lays out at least the Figma width', (tester) async {
    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.delivered)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.minWidth, 86);
  });

  // Regression: a fixed (not minimum) width of 86 wrapped "In progress" onto
  // a second line, because the platform font substituted for the unbundled
  // Inter (AppTypography.fontFamilyBody's doc comment) renders it wider than
  // 86 minus padding on a real device (Figma node 706:3032 fits it on one
  // line). `flutter_test`'s own fallback font has different metrics again, so
  // this checks the properties that force one line rather than a measured
  // width, which a widget test can't reproduce faithfully either way.
  testWidgets('never wraps the label, however wide it renders', (tester) async {
    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.inProgress)),
    );

    final text = tester.widget<Text>(find.text('In progress'));
    expect(text.maxLines, 1);
    // No maxWidth constraint on the pill's own BoxConstraints: it hugs
    // whatever the label needs instead of clamping it down to 86 and
    // forcing a wrap.
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, double.infinity);
  });
}
