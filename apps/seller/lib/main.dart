import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shopscroll_shared/backend/clerk_backed_client.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/coming_soon_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/seller_session_controller.dart';
import 'core/config/backend_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Unlike the buyer app there is no mock data to fall back to: without the
  // connection values the app shows the placeholder only.
  if (!BackendConfig.isConfigured) {
    runApp(const SellerApp());
    return;
  }

  final clerkAuthState = await ClerkAuthState.create(
    config: ClerkAuthConfig(publishableKey: BackendConfig.clerkPublishableKey),
  );
  // Only the Clerk backed client exists here, never an anonymous session
  // (spec 0012, AC-7).
  final client = buildClerkBackedClient(
    BackendConfig.supabaseUrl,
    BackendConfig.supabasePublishableKey,
    () async => (await clerkAuthState.sessionToken()).jwt,
  );

  runApp(SellerApp(clerkAuthState: clerkAuthState, client: client));
}

/// Seller app shell (spec 0011, spec 0012): the shared theme, a required sign
/// in, and a placeholder behind it. Seller features get their own scope rows
/// and specs.
///
/// With no [clerkAuthState] (backend not configured) it shows the placeholder
/// directly.
class SellerApp extends StatefulWidget {
  const SellerApp({super.key, this.clerkAuthState, this.client});

  final ClerkAuthState? clerkAuthState;
  final SupabaseClient? client;

  @override
  State<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends State<SellerApp> {
  SellerSessionController? _session;

  @override
  void initState() {
    super.initState();
    final clerkAuthState = widget.clerkAuthState;
    final client = widget.client;
    if (clerkAuthState != null && client != null) {
      _session = SellerSessionController(
        clerkAuth: clerkAuthState,
        client: client,
      );
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = ComingSoonScreen(
      label: 'Seller app',
      icon: Icons.storefront,
    );
    final clerkAuthState = widget.clerkAuthState;

    final app = MaterialApp(
      title: 'Shopscroll Seller',
      theme: AppTheme.light,
      home: clerkAuthState == null
          ? placeholder
          : ClerkAuthBuilder(
              signedInBuilder: (context, authState) => placeholder,
              signedOutBuilder: (context, authState) =>
                  const Scaffold(body: SafeArea(child: ClerkAuthentication())),
            ),
      builder: clerkAuthState == null
          ? null
          : (context, child) => ClerkErrorListener(child: child!),
    );

    if (clerkAuthState == null) return app;
    return ClerkAuth(authState: clerkAuthState, child: app);
  }
}
