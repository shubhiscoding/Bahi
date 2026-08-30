import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user.dart';
import '../../../core/services/supabase_client.dart';

/// Stream of auth sessions (listens to Supabase auth changes)
final authSessionProvider = StreamProvider<AuthState>((ref) {
  return SupabaseClientService.auth.onAuthStateChange.map((event) {
    return AuthState(
      session: event.session,
      user: event.session?.user,
    );
  });
});

/// Current authenticated user profile from Supabase
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) return null;

  try {
    final response = await SupabaseClientService.client
        .from('profiles')
        .select()
        .eq('id', authState.user!.id)
        .single();

    return User.fromJson(response);
  } catch (e) {
    print('Error fetching user profile: $e');
    return null;
  }
});

/// Current user's businesses
final userBusinessesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  try {
    final businesses = await SupabaseClientService.client
        .from('business_members')
        .select('businesses(*)')
        .eq('user_id', user.id);

    return List<Map<String, dynamic>>.from(businesses);
  } catch (e) {
    print('Error fetching user businesses: $e');
    return [];
  }
});

/// Sign in with Google
final googleSignInProvider = FutureProvider.autoDispose<void>((ref) async {
  try {
    await SupabaseClientService.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://callback/',
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

/// Auth state model
class AuthState {
  final Session? session;
  final GotrueUser? user;

  AuthState({
    required this.session,
    required this.user,
  });

  bool get isAuthenticated => user != null;
}
