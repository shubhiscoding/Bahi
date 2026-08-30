import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User; // Hide User from supabase to avoid conflict with our User model
import '../../../core/models/user.dart';
import '../../../core/services/supabase_client.dart';

/// Auth state model
class AuthState {
  final Session? session;
  final AuthUser? user;

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
      OAuthProvider.google,
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
