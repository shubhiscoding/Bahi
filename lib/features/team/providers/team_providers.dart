import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/team_repository.dart';

/// Realtime stream of team members (joined with profile names) for the
/// current business.
final teamMembersProvider = StreamProvider<List<TeamMember>>((ref) async* {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) {
    yield <TeamMember>[];
    return;
  }

  final rowsStream = TeamRepository.watchMemberRows(business.id);

  await for (final rows in rowsStream) {
    final names = await TeamRepository.fetchProfileNames(
      rows.map((r) => r.userId).toList(),
    );
    yield rows
        .map((row) => TeamMember(row: row, fullName: names[row.userId] ?? '?'))
        .toList();
  }
});

/// Current user's role in the current business ('owner' | 'member' | null)
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) return null;

  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return null;

  return TeamRepository.getUserRole(
    businessId: business.id,
    userId: authState.user!.id,
  );
});

/// Remove a member (owner-only, enforced by RLS)
final removeMemberProvider =
    FutureProvider.autoDispose.family<void, String>((ref, userId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  await TeamRepository.removeMember(businessId: business.id, userId: userId);
});
