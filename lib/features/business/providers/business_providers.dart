import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/business.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../repositories/business_repository.dart';

/// Create a new business (backend derives owner from the JWT)
final createBusinessProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, businessName) async {
  final authState = ref.watch(authSessionProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }

  return BusinessRepository.createBusiness(businessName: businessName);
});

/// Join a business by invite code (backend derives user from the JWT)
final joinBusinessProvider =
    FutureProvider.autoDispose.family<void, String>((ref, inviteCode) async {
  final authState = ref.watch(authSessionProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }

  await BusinessRepository.joinBusinessByCode(inviteCode: inviteCode);
});

/// Get all businesses for current user.
///
/// Watches ref.watch(authSessionProvider) (the AsyncValue, not .future) so
/// this reliably re-runs on every sign-in/sign-out transition — not just
/// the first time authSessionProvider resolves.
final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final authState = ref.watch(authSessionProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return [];

  return BusinessRepository.getUserBusinesses();
});

/// Current selected business (first one for now; can be expanded to user
/// selection). Deliberately does NOT catch errors into null — a real
/// fetch failure should surface as a retryable error (AppRouter shows an
/// error screen), not get miscached as "this user has no business",
/// which previously caused a business owner to be wrongly routed back to
/// Create/Join after a transient error during re-login.
final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final businesses = await ref.watch(userBusinessesProvider.future);
  return businesses.isNotEmpty ? businesses[0] : null;
});

/// Generates a fresh 5-minute, single-use invite code — call right when
/// the user taps "Share" (design.md rule 12: OTP-style, matches the
/// UPI/banking mental model this audience already knows).
final generateInviteCodeProvider =
    FutureProvider.autoDispose.family<InviteCode, String>((ref, businessId) {
  return BusinessRepository.generateInviteCode(businessId);
});
