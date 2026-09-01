import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/active_supabase_client.dart';
import 'core/auth/auth_session_controller.dart';
import 'core/config/clerk_config.dart';
import 'core/config/supabase_config.dart';
import 'core/onboarding/onboarding_prefs.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repository_providers.dart';
import 'data/repositories/supabase/supabase_cart_repository.dart';
import 'data/repositories/supabase/supabase_order_repository.dart';
import 'data/repositories/supabase/supabase_product_repository.dart';
import 'data/repositories/supabase/supabase_reel_repository.dart';
import 'data/repositories/supabase/supabase_user_profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Whether the first launch welcome screen (spec 0004, AC-1) has already
  // been shown on this device; loaded up front so both early return
  // branches below can still override the provider, even though the
  // welcome screen itself only ever shows once Clerk is configured.
  final onboardingPrefs = OnboardingPrefs(await SharedPreferences.getInstance());

  // No SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY passed (see .env.example):
  // run entirely on mock data, same as before this feature existed.
  if (!SupabaseConfig.isConfigured) {
    runApp(
      ProviderScope(
        overrides: [
          onboardingPrefsProvider.overrideWithValue(onboardingPrefs),
        ],
        child: const MarketplaceApp(),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // The anonymous capable client (spec 0003), unchanged: native auth,
  // reused across launches. Reuse a persisted session if one exists; only
  // mint a new anonymous identity when there truly is none.
  final anonymousClient = Supabase.instance.client;
  final anonymousAuth = anonymousClient.auth;
  if (anonymousAuth.currentSession == null) {
    await anonymousAuth.signInAnonymously();
  }

  if (!ClerkConfig.isConfigured) {
    // Clerk not wired up yet (no CLERK_PUBLISHABLE_KEY): behave exactly as
    // spec 0003, anonymous only, single client.
    runApp(
      ProviderScope(
        overrides: [
          onboardingPrefsProvider.overrideWithValue(onboardingPrefs),
          productRepositoryProvider.overrideWithValue(
            SupabaseProductRepository(anonymousClient),
          ),
          reelRepositoryProvider.overrideWithValue(
            SupabaseReelRepository(anonymousClient),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            SupabaseUserProfileRepository(anonymousClient),
          ),
          cartRepositoryProvider.overrideWithValue(
            SupabaseCartRepository(anonymousClient),
          ),
          orderRepositoryProvider.overrideWithValue(
            SupabaseOrderRepository(anonymousClient),
          ),
        ],
        child: const MarketplaceApp(),
      ),
    );
    return;
  }

  // Clerk (spec 0004): a second Supabase client, backed by Clerk's session
  // token instead of Supabase's own auth. Two clients, not one — see
  // core/auth/active_supabase_client.dart for why they cannot be merged
  // into a single client instance.
  final clerkAuthState = await ClerkAuthState.create(
    config: ClerkAuthConfig(publishableKey: ClerkConfig.publishableKey),
  );

  // First launch, and nobody is already signed in for real: open on the
  // welcome screen (spec 0004, AC-1). Either way this is a one time
  // decision made here, not re-evaluated by the router later. In debug
  // builds, always open on welcome instead, so the sign-in flow is there
  // to test on every run without clearing onboarding prefs or session
  // state by hand; release builds are unaffected.
  final showWelcome = kDebugMode ||
      (!onboardingPrefs.hasSeenWelcome && !clerkAuthState.isSignedIn);

  final clerkBackedClient = buildClerkBackedClient(
    SupabaseConfig.url,
    SupabaseConfig.publishableKey,
    () async => (await clerkAuthState.sessionToken()).jwt,
  );

  runApp(
    ProviderScope(
      overrides: [
        activeSupabaseClientProvider.overrideWith((ref) => anonymousClient),
        onboardingPrefsProvider.overrideWithValue(onboardingPrefs),
        initialLocationProvider.overrideWithValue(
          showWelcome ? '/welcome' : '/',
        ),
        productRepositoryProvider.overrideWith(
          (ref) =>
              SupabaseProductRepository(ref.watch(activeSupabaseClientProvider)),
        ),
        reelRepositoryProvider.overrideWith(
          (ref) =>
              SupabaseReelRepository(ref.watch(activeSupabaseClientProvider)),
        ),
        userProfileRepositoryProvider.overrideWith(
          (ref) => SupabaseUserProfileRepository(
            ref.watch(activeSupabaseClientProvider),
          ),
        ),
        cartRepositoryProvider.overrideWith(
          (ref) =>
              SupabaseCartRepository(ref.watch(activeSupabaseClientProvider)),
        ),
        orderRepositoryProvider.overrideWith(
          (ref) =>
              SupabaseOrderRepository(ref.watch(activeSupabaseClientProvider)),
        ),
      ],
      child: MarketplaceApp(
        clerkAuthState: clerkAuthState,
        anonymousClient: anonymousClient,
        clerkBackedClient: clerkBackedClient,
      ),
    ),
  );
}

class MarketplaceApp extends ConsumerStatefulWidget {
  const MarketplaceApp({
    super.key,
    this.clerkAuthState,
    this.anonymousClient,
    this.clerkBackedClient,
  });

  /// Null when Clerk is not configured: the app runs anonymous only, same
  /// as spec 0003, with no ClerkAuth wrapper and no dual client.
  final ClerkAuthState? clerkAuthState;
  final SupabaseClient? anonymousClient;
  final SupabaseClient? clerkBackedClient;

  @override
  ConsumerState<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends ConsumerState<MarketplaceApp> {
  AuthSessionController? _authSessionController;

  @override
  void initState() {
    super.initState();
    final clerkAuthState = widget.clerkAuthState;
    final anonymousClient = widget.anonymousClient;
    final clerkBackedClient = widget.clerkBackedClient;
    if (clerkAuthState != null &&
        anonymousClient != null &&
        clerkBackedClient != null) {
      _authSessionController = AuthSessionController(
        ref: ref,
        clerkAuth: clerkAuthState,
        anonymousClient: anonymousClient,
        clerkBackedClient: clerkBackedClient,
      );
    }
  }

  @override
  void dispose() {
    _authSessionController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clerkAuthState = widget.clerkAuthState;
    final router = ref.watch(appRouterProvider);
    final app = MaterialApp.router(
      title: 'ShopScroll',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // Turns every Clerk sign in/up error (a rejected password, a taken
      // username, and so on) into a visible snack bar instead of failing
      // silently (spec 0004, AC-12). Only wired when Clerk is configured:
      // ClerkErrorListener needs a ClerkAuth ancestor, which only exists
      // below, and only when clerkAuthState is non null.
      builder: clerkAuthState == null
          ? null
          : (context, child) => ClerkErrorListener(child: child!),
    );

    if (clerkAuthState == null) return app;

    return ClerkAuth(authState: clerkAuthState, child: app);
  }
}
