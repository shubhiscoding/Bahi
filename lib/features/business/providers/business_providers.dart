import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/business.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../repositories/business_repository.dart';

/// Create a new business (backend derives owner from the JWT)
final createBusinessProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, businessName) async {
  // Ensure there's a session before calling the backend
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) {
    throw Exception('Not authenticated');
  }

  return BusinessRepository.createBusiness(businessName: businessName);
});

/// Join a business by invite code (backend derives user from the JWT)
final joinBusinessProvider =
    FutureProvider.autoDispose.family<void, String>((ref, inviteCode) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) {
    throw Exception('Not authenticated');
  }

  await BusinessRepository.joinBusinessByCode(inviteCode: inviteCode);
});

/// Get all businesses for current user
final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) return [];

  return BusinessRepository.getUserBusinesses();
});

/// Current selected business (first one for now; can be expanded to user selection)
final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  try {
    final businesses = await ref.watch(userBusinessesProvider.future);
    return businesses.isNotEmpty ? businesses[0] : null;
  } catch (e) {
    print('Error getting current business: $e');
    return null;
  }
});
