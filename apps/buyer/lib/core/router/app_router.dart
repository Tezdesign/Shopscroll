import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/activity/order_receipt_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/catalog/home_screen.dart';
import '../../features/catalog/product_detail_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_confirmation_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/onboarding/email_address_screen.dart';
import '../../features/onboarding/enable_notifications_screen.dart';
import '../../features/onboarding/get_started_screen.dart';
import '../../features/onboarding/interests_screen.dart';
import '../../features/onboarding/log_in_screen.dart';
import '../../features/onboarding/phone_number_screen.dart';
import '../../features/onboarding/setting_up_account_screen.dart';
import '../../features/onboarding/sign_in_verification.dart';
import '../../features/onboarding/sign_up_verification.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_anonymous_view.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/seller_application/seller_application_screen.dart';
import '../../features/seller_application/seller_application_wizard_screen.dart';
import '../../features/reels/reel_player_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/store/store_area_screen.dart';
import '../../features/store/store_page_screen.dart';
import 'package:shopscroll_shared/widgets/coming_soon_screen.dart';
import '../config/clerk_config.dart';
import '../onboarding/onboarding_prefs.dart';
import 'app_shell.dart';

/// Where [appRouterProvider] opens the app: `/welcome` the first time a
/// device is seen (and nobody is already signed in), `/` every time after
/// that. `main.dart` overrides this once, at startup, from
/// [OnboardingPrefs] and the Clerk session; nothing in the router itself
/// re-evaluates it later (spec 0004, AC-1).
final initialLocationProvider = Provider<String>((ref) => '/');

/// Root router. A [StatefulShellRoute] holds the 5 bottom nav tabs (Home,
/// Discover, Reels, Activity, Profile) as branches under [AppShell], so
/// switching tabs preserves each one's own navigation stack and scroll
/// position (see spec 0001). Activity is [ActivityScreen] (spec 0008), with
/// its `orders/:id` child as [OrderReceiptScreen] and `chat/:id` still a
/// coming soon page; Profile is
/// the real page from spec 0005 once Clerk is configured ([ProfileScreen] signed in, [ProfileAnonymousView]
/// signed out), and falls back to the same placeholder when Clerk isn't
/// configured at all (no `ClerkAuth` ancestor to read in that case).
///
/// `/welcome`, `/sign-up` ([GetStartedScreen], the first step of the
/// redesigned sign up flow — see `lib/features/onboarding/AGENTS.md`) →
/// `/sign-up/phone` ([PhoneNumberScreen]) ⇄ `/sign-up/email`
/// ([EmailAddressScreen]) (spec 0004, AC-1), `/profile/edit` (spec 0005,
/// AC-5), plus product detail, the Reels full screen player, and the Store
/// Page ([StorePageScreen], spec 0010), stay top level routes, outside the
/// shell, so they open full screen without the bottom nav.
///
/// `/store` ([StoreAreaScreen], spec 0014) is the store area, a placeholder
/// that only a seller stays in, and `/apply` is the seller application for a
/// visitor with no account. Both are top level.
///
/// `/cart` ([CartScreen], spec 0007) is a child route of the Home branch's
/// root route, so the tab bar keeps showing with Home highlighted.
/// `/checkout` ([CheckoutScreen]) and `/order-confirmation/:id`
/// ([OrderConfirmationScreen]) are top level (spec 0009), so they open full
/// screen without the tab bar. A signed in buyer's id fills the contact, and
/// the confirmation shows its Sign in block only when signed out.
///
/// `/search` and `/discover/search` ([SearchScreen], spec 0006) are each a
/// child route of their branch's own root route instead, so they stay
/// inside the shell: the bottom nav bar keeps showing, with the tab you
/// opened search from still highlighted, and `Cancel`/back just pops back
/// to that tab's own stack.
///
/// Both sign up paths are wired to Clerk through [SignUpVerification] (spec
/// 0004, AC-2): `/sign-up` stores the name and username in
/// [signUpDraftProvider], and `/sign-up/phone` and `/sign-up/email` each
/// create the sign up, send the code and verify it. A verified sign up lands
/// on `/sign-up/interests` ([InterestsScreen]), then
/// `/sign-up/notifications` ([EnableNotificationsScreen]) and
/// `/sign-up/setting-up` ([SettingUpAccountScreen]), which opens the home
/// screen once it finishes. `/sign-in` (Log in) is [LogInScreen], the same
/// identifier then one time code pattern in a single screen, wired to Clerk
/// by [SignInVerification]; it goes straight to the home screen on success
/// rather than through the sign up tail.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'cart',
                    builder: (context, state) => const CartScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reels',
                builder: (context, state) => const ReelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
                routes: [
                  GoRoute(
                    path: 'orders/:id',
                    builder: (context, state) => OrderReceiptScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chat/:id',
                    builder: (context, state) => const ComingSoonScreen(
                      label: 'Chat',
                      icon: Icons.chat_bubble_outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => ClerkConfig.isConfigured
                    ? ClerkAuthBuilder(
                        signedInBuilder: (context, authState) =>
                            ProfileScreen(authState: authState),
                        signedOutBuilder: (context, authState) =>
                            const ProfileAnonymousView(),
                      )
                    : const ComingSoonScreen(
                        label: 'Profile',
                        icon: Icons.person_outline,
                      ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onSignUp: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.push('/sign-up');
          },
          onLogIn: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.push('/sign-in');
          },
          onSkip: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.go('/');
          },
          onApplyNow: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.push('/apply');
          },
        ),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) {
          // Null when Clerk isn't configured, and the screen then runs as UI
          // only, advancing through its stages against no backend.
          final signIn = SignInVerification.maybe(context, ref);
          return LogInScreen(
            onSendCode: signIn?.sendCode ?? (channel, identifier) async => true,
            onVerify:
                signIn?.verify ?? (channel, identifier, code, type) async {},
            onResendCode: signIn?.resendCode ?? (channel, identifier) async {},
            onSignUp: () => context.push('/sign-up'),
            onApplyNow: () => context.push('/apply'),
          );
        },
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => GetStartedScreen(
          // Held in signUpDraftProvider until a later step has an address or
          // number to create the Clerk sign up with (spec 0004, AC-14).
          onContinue: (fullName, username) {
            ref.read(signUpDraftProvider.notifier).state = (
              fullName: fullName,
              username: username,
            );
            context.push('/sign-up/phone');
          },
        ),
      ),
      GoRoute(
        path: '/sign-up/phone',
        builder: (context, state) {
          // Null when Clerk isn't configured, and the screen then runs as UI
          // only, advancing through its stages against no backend.
          final signUp = SignUpVerification.phone(context, ref);
          return PhoneNumberScreen(
            onSendCode: signUp?.sendCode ?? (phoneNumber) async => true,
            onVerify: signUp?.verify ?? (phoneNumber, code) {},
            onResendCode: signUp?.resendCode ?? (phoneNumber) {},
            onUseEmailInstead: () => context.push('/sign-up/email'),
          );
        },
      ),
      GoRoute(
        path: '/sign-up/email',
        builder: (context, state) {
          final signUp = SignUpVerification.email(context, ref);
          return EmailAddressScreen(
            onSendCode: signUp?.sendCode ?? (email) async => true,
            onVerify: signUp?.verify ?? (email, code) {},
            onResendCode: signUp?.resendCode ?? (email) {},
            onUsePhoneInstead: () => context.pop(),
          );
        },
      ),
      GoRoute(
        path: '/sign-up/interests',
        builder: (context, state) => InterestsScreen(
          // Nothing consumes the chosen categories yet: no interests field
          // exists on the profile, and the catalog does not filter by them.
          onStart: (selected) => context.go('/sign-up/notifications'),
        ),
      ),
      GoRoute(
        path: '/sign-up/notifications',
        builder: (context, state) => EnableNotificationsScreen(
          // Both choices go the same way: the app has no push setup to ask
          // permission through yet (no messaging plugin, no APNs/FCM keys),
          // so Enable can only record the intent, which is to say nothing.
          onEnable: () => context.go('/sign-up/setting-up'),
          onRemindLater: () => context.go('/sign-up/setting-up'),
        ),
      ),
      GoRoute(
        path: '/sign-up/setting-up',
        builder: (context, state) =>
            SettingUpAccountScreen(onDone: () => context.go('/')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      // Settings, Seller application (spec 0013). Signed in only: an anonymous
      // visitor gets the same sign in prompt as the Profile tab.
      GoRoute(
        path: '/profile/seller-application',
        builder: (context, state) => ClerkConfig.isConfigured
            ? ClerkAuthBuilder(
                signedInBuilder: (context, authState) =>
                    SellerApplicationScreen(userId: authState.user!.id),
                signedOutBuilder: (context, authState) =>
                    const ProfileAnonymousView(),
              )
            : const SellerApplicationScreen(),
      ),
      GoRoute(
        path: '/profile/seller-application/new',
        builder: (context, state) => ClerkConfig.isConfigured
            ? ClerkAuthBuilder(
                signedInBuilder: (context, authState) =>
                    const SellerApplicationWizardScreen(),
                signedOutBuilder: (context, authState) =>
                    const ProfileAnonymousView(),
              )
            : const SellerApplicationWizardScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => ClerkConfig.isConfigured
            ? ClerkAuthBuilder(
                signedInBuilder: (context, authState) =>
                    CheckoutScreen(signedInUserId: authState.user!.id),
                builder: (context, authState) => const CheckoutScreen(),
              )
            : const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order-confirmation/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return ClerkConfig.isConfigured
              ? ClerkAuthBuilder(
                  signedInBuilder: (context, authState) =>
                      OrderConfirmationScreen(
                        orderId: orderId,
                        isSignedIn: true,
                      ),
                  builder: (context, authState) =>
                      OrderConfirmationScreen(orderId: orderId),
                )
              : OrderConfirmationScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reels/:id',
        builder: (context, state) => ReelPlayerScreen(
          initialReelId: state.pathParameters['id']!,
          orderedReelIds: state.extra as List<String>?,
        ),
      ),
      // The store area (spec 0014): a placeholder only a seller stays in.
      GoRoute(
        path: '/store',
        builder: (context, state) => const StoreAreaScreen(),
      ),
      // "Apply now" for a person with no account (spec 0014, AC-7). Someone
      // already signed in applies from Settings, Seller application instead.
      GoRoute(
        path: '/apply',
        builder: (context, state) => ClerkConfig.isConfigured
            ? ClerkAuthBuilder(
                signedInBuilder: (context, authState) =>
                    SellerApplicationScreen(userId: authState.user!.id),
                builder: (context, authState) =>
                    const SellerApplicationWizardScreen(isVisitor: true),
              )
            : const SellerApplicationWizardScreen(isVisitor: true),
      ),
      GoRoute(
        path: '/store/:id',
        builder: (context, state) =>
            StorePageScreen(storeId: state.pathParameters['id']!),
      ),
    ],
  );
});
