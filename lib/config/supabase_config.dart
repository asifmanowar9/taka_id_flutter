/// Supabase project credentials for the Flutter client.
///
/// Dashboard → Project Settings → API → Publishable and secret API keys
abstract final class SupabaseConfig {
  /// Project URL — the same value as SUPABASE_URL in backend/.env.
  static const String url = 'https://diywtfwhrxunjtjqcjrm.supabase.co';

  /// Publishable key (safe to ship in the app — with RLS enabled).
  /// Dashboard → API Keys → Publishable key → copy the full value.
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRpeXd0Zndocnh1bmp0anFjanJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0MzE0MTMsImV4cCI6MjA4ODAwNzQxM30.iMSl8oACksHQIa8uU5SToIYDXZEy5amf3J8MUiNWFm0';
}
