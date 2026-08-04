/// Clerk connection value, injected at build/run time with --dart-define
/// (never committed). See .env.example for the variable name and where to
/// find the real value in the Clerk dashboard. Only the publishable key
/// belongs here: Clerk's secret key and webhook signing secret are server
/// side only (Supabase Edge Function secrets), never a --dart-define
/// (spec 0004).
class ClerkConfig {
  const ClerkConfig._();

  static const publishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;
}
