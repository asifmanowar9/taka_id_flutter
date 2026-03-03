/// Copy this file to supabase_config.dart and fill in your real values.
/// supabase_config.dart is gitignored — never commit real keys.
///
/// Dashboard → Project Settings → API → Publishable and secret API keys
abstract final class SupabaseConfig {
  /// Project URL — same as SUPABASE_URL in backend/.env.
  static const String url = 'https://YOUR_PROJECT_REF.supabase.co';

  /// Publishable (anon) key — safe to ship in the app with RLS enabled.
  /// Dashboard → API Keys → Publishable key → copy the full value.
  static const String anonKey = 'YOUR_ANON_KEY_HERE';
}
