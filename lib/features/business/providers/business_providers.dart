import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/business.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../repositories/business_repository.dart';

/// Create a new business
final createBusinessProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, businessName) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) throw Exception('Not authenticated');

  return BusinessRepository.createBusiness(
    ownerId: authState.user!.id,
    businessName: businessName,
  );
});

/// Join a business by invite code
final joinBusinessProvider =
    FutureProvider.autoDispose.family<void, String>((ref, inviteCode) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) throw Exception('Not authenticated');

  await BusinessRepository.joinBusinessByCode(
    userId: authState.user!.id,
    inviteCode: inviteCode,
  );
});

/// Get all businesses for current user
final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) return [];

  return BusinessRepository.getUserBusinesses(authState.user!.id);
});

/// Current selected business (first one for now; can be expanded to user selection)
final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final businesses = await ref.watch(userBusinessesProvider.future);
  return businesses.isNotEmpty ? businesses[0] : null;
});
