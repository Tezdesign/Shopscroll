/// Connection values for the one backend both apps share (spec 0012): the same
/// Supabase project and the same Clerk instance as the buyer app. Injected at
/// build/run time with --dart-define (never committed), see .env.example.
class BackendConfig {
  const BackendConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      clerkPublishableKey.isNotEmpty;
}
