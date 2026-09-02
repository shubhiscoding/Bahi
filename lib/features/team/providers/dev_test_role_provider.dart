import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../business/providers/business_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import 'team_providers.dart';

/// Dev-only: flips the current (real, already signed-in) user's own role
/// on the seeded dev business between 'owner' and 'member', via the
/// backend's /dev/test-role route (only mounted when DEV_MODE=true —
/// never in prod). Lets both views be tested from one real account
/// without re-authenticating. Gated in the UI by isLocalBackend.
final devTestRoleProvider = FutureProvider.autoDispose.family<void, String>((ref, role) async {
  await ApiClient.instance.post('/dev/test-role', data: {'role': role});

  // Refresh everything that depends on role/membership.
  ref.invalidate(currentUserRoleProvider);
  ref.invalidate(userBusinessesProvider);
  ref.invalidate(currentBusinessProvider);
  ref.invalidate(teamMembersProvider);
  ref.invalidate(inventoryItemsProvider);
});
