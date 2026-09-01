import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/profile/profile_anonymous_view.dart';

void main() {
  Widget wrapWithRouter() {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileAnonymousView(),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (context, state) =>
              const Scaffold(body: Text('Sign in screen')),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }

  testWidgets('renders a gentle explanation and a single CTA button', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithRouter());

    expect(find.text('Sign in to see your profile'), findsOneWidget);
    expect(
      find.textContaining('once you have signed in'),
      findsOneWidget,
    );
    expect(find.text('Sign up or log in'), findsOneWidget);
  });

  testWidgets('tapping the CTA navigates to /sign-in', (tester) async {
    await tester.pumpWidget(wrapWithRouter());

    await tester.tap(find.text('Sign up or log in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in screen'), findsOneWidget);
  });
}
