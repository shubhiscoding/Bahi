import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../../core/models/user.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/supabase_client.dart';

/// Auth state model
class AuthState {
  final supa.Session? session;
  final supa.User? user;

  AuthState({
    required this.session,
    required this.user,
  });

  bool get isAuthenticated => user != null;
}

/// Stream of auth sessions (listens to Supabase auth changes)
final authSessionProvider = StreamProvider<AuthState>((ref) {
  return SupabaseClientService.auth.onAuthStateChange.map((authEvent) {
    return AuthState(
      session: authEvent.session,
      user: authEvent.session?.user,
    );
  });
});

/// Sign in with Google
final googleSignInProvider = FutureProvider.autoDispose<void>((ref) async {
  try {
    await SupabaseClientService.auth.signInWithOAuth(
      supa.OAuthProvider.google,
      redirectTo: 'com.example.bahi://callback',
    );
  } catch (e) {
    print('Google sign-in error: $e');
    rethrow;
  }
});

/// Sign out
final signOutProvider = FutureProvider.autoDispose<void>((ref) async {
  try {
    await SupabaseClientService.auth.signOut();
  } catch (e) {
    print('Sign-out error: $e');
    rethrow;
  }
});

/// Current user's profile row (full_name etc.) — used for the persistent
/// avatar header (design.md rule 4) and "edited by" attribution (rule 10).
///
/// Calls POST /auth/sync (idempotent upsert) rather than a separate
/// read-only endpoint, so the backend's profiles row is always kept in
/// sync with the JWT's latest claims without a separate "call this once
/// after sign-in" step to wire up.
final currentUserProfileProvider = FutureProvider<User?>((ref) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) return null;

  try {
    final response = await ApiClient.instance.post('/auth/sync');
    return User.fromJson(response.data);
  } catch (e) {
    print('Error syncing user profile: $e');
    return null;
  }
});
