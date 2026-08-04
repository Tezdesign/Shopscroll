/// Supabase connection values, injected at build/run time with --dart-define
/// (never committed). See .env.example for the variable names and where to
/// find the real values in the Supabase dashboard.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
