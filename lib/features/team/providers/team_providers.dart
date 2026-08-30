import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/business.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/team_repository.dart';

/// Live stream of team members (REST fetch + Socket.IO patches) for the
/// current business.
final teamMembersProvider = StreamProvider<List<BusinessMember>>((ref) {
  final businessAsync = ref.watch(currentBusinessProvider);

  return businessAsync.when(
    data: (business) {
      if (business == null) return Stream.value(<BusinessMember>[]);
      return TeamRepository.watchMembers(business.id);
    },
    loading: () => Stream.value(<BusinessMember>[]),
    error: (err, stack) => Stream.value(<BusinessMember>[]),
  );
});

/// Current user's role in the current business ('owner' | 'member' | null).
/// Uses ref.watch(authSessionProvider).valueOrNull (not .future) so this
/// reliably re-runs on every auth transition — same fix as
/// currentBusinessProvider/currentUserProfileProvider.
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authSessionProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return null;

  return TeamRepository.getUserRole(
    businessId: business.id,
    userId: authState.user!.id,
  );
});

/// Remove a member (owner-only, enforced by backend middleware)
final removeMemberProvider =
    FutureProvider.autoDispose.family<void, String>((ref, userId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  await TeamRepository.removeMember(businessId: business.id, userId: userId);
});

/// Leave the current business (self-removal). Owner cannot leave —
/// enforced server-side (403 OWNER_CANNOT_LEAVE).
final leaveBusinessProvider = FutureProvider.autoDispose<void>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  await TeamRepository.leaveBusiness(business.id);

  // Same invalidation pattern as sign-out: without this, the now-stale
  // business/inventory/team providers would keep showing data for a
  // business this user is no longer a member of.
  ref.invalidate(userBusinessesProvider);
  ref.invalidate(currentBusinessProvider);
});
