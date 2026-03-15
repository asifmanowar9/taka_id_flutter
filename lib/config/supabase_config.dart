/// Supabase project credentials for the Flutter client.
///
/// Values come from build-time defines:
///   --dart-define=SUPABASE_URL=...
///   --dart-define=SUPABASE_ANON_KEY=...
abstract final class SupabaseConfig {
  /// Project URL — the same value as SUPABASE_URL in backend/.env.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Publishable key (safe to ship in the app — with RLS enabled).
  /// Dashboard → API Keys → Publishable key → copy the full value.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
