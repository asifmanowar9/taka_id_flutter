import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Supabase client ───────────────────────────────────────────────────────────

/// The raw Supabase client. Use for auth calls and direct queries.
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── Auth state ────────────────────────────────────────────────────────────────

/// Stream of every auth state change (sign-in, sign-out, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The currently authenticated user, or null when signed out.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session?.user;
});

/// The current session's JWT access token, injected into API requests.
/// Returns null when not authenticated.
final accessTokenProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session?.accessToken;
});
