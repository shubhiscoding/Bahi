import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../../core/models/user.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/supabase_client.dart';
import '../../business/providers/business_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../team/providers/team_providers.dart';

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

/// Sign out.
///
/// Explicitly invalidates every user-scoped provider and disconnects the
/// socket. Without this, a second user signing in on the same device
/// before these providers naturally refresh could briefly see the
/// previous user's cached business/inventory/team data — not just a UX
/// bug, a real data-leak risk on a shared device (which this app's users
/// commonly are, per design.md).
final signOutProvider = FutureProvider.autoDispose<void>((ref) async {
  try {
    await SupabaseClientService.auth.signOut();
  } catch (e) {
    print('Sign-out error: $e');
    rethrow;
  } finally {
    SocketService.disconnect();
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(userBusinessesProvider);
    ref.invalidate(currentBusinessProvider);
    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(teamMembersProvider);
    ref.invalidate(currentUserRoleProvider);
  }
});

/// Current user's profile row (full_name etc.) — used for the persistent
/// avatar header (design.md rule 4) and "edited by" attribution (rule 10).
///
/// Calls POST /auth/sync (idempotent upsert) rather than a separate
/// read-only endpoint, so the backend's profiles row is always kept in
/// sync with the JWT's latest claims without a separate "call this once
/// after sign-in" step to wire up.
///
/// Uses ref.watch(authSessionProvider) (the AsyncValue, not .future) so
/// this reliably re-runs on every auth transition, and does NOT swallow
/// errors into a cached "null" — a transient failure right after sign-in
/// should surface as a retryable error, not get permanently miscached as
/// "this user has no profile" (which is exactly what caused a business
/// owner to be wrongly shown Create/Join again after logging back in).
///
/// Phase 12 follow-up: this was the actual cause of "कुछ गलत हुआ" on a
/// fully offline cold-start (already-signed-in user) — this call sits in
/// AppRouter BEFORE currentBusinessProvider (which already has a cache
/// fallback), so it failed and blocked the router before that fix ever
/// got a chance to run. Cache key is scoped to the signed-in user's own
/// id (not a shared/global key) — this app can be used on a shared
/// device by different accounts (see signOutProvider's comment above),
/// so a second user's offline first-ever launch must NOT fall back to
/// whatever a previous user's profile happened to be cached as.
final currentUserProfileProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authSessionProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  return LocalCacheService.fetchWithFallback<User>(
    key: 'profile:${authState.user!.id}',
    fetch: () async {
      final response = await ApiClient.instance.post('/auth/sync');
      return User.fromJson(response.data);
    },
    toJson: (u) => u.toJson(),
    fromJson: User.fromJson,
  );
});
