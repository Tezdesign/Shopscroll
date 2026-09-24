import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/features/search/search_screen.dart';

void main() {
  Widget wrapWithRouter() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/search'),
                child: const Text('Open search'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) => Scaffold(
            body: Text('Product ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('nothing typed shows one tile per real product category (AC-3)', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());
    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);

    expect(find.text('Popular categories'), findsOneWidget);
    expect(find.text('Fashion'), findsOneWidget);
    expect(find.text('Tech'), findsOneWidget);
  });

  testWidgets('typing shows the Items/Stores tabs and suggestions (AC-4, AC-5)', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());
    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);

    await tester.enterText(find.byType(TextField), 'air');
    await tester.pump();

    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Air Max 270', findRichText: true), findsOneWidget);
  });

  testWidgets('typing text that matches nothing shows the no results message (AC-10)', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());
    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);

    await tester.enterText(find.byType(TextField), 'zzznotfound');
    await tester.pump();

    expect(find.text('No results found for "zzznotfound"'), findsOneWidget);
  });

  testWidgets('tapping a suggestion opens the results view with a heading (AC-6, AC-7)', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());
    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);

    await tester.enterText(find.byType(TextField), 'air');
    await tester.pump();
    await tester.tap(find.text('Air Max 270', findRichText: true));
    await tester.pump();

    expect(find.text('Results for "Air Max 270"'), findsOneWidget);
  });

  testWidgets('Cancel returns to the screen it was opened from (AC-2)', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());
    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open search'), findsOneWidget);
  });
}
