import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/order_status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
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

  testWidgets('lays out at the fixed width', (tester) async {
    await tester.pumpWidget(
      wrap(const OrderStatusBadge(status: OrderStatus.delivered)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, 86);
  });
}
