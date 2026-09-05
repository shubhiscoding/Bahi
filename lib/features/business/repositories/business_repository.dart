import '../../../core/models/business.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';

/// Business repository — calls the Node/Express backend instead of
/// Supabase directly. All authorization now lives in the backend
/// (middleware/businessAccess.ts) instead of RLS.
class BusinessRepository {
  static Future<Business> createBusiness({
    required String businessName,
  }) async {
    final response = await ApiClient.instance.post(
      '/businesses',
      data: {'name': businessName},
    );
    return Business.fromJson(response.data);
  }

  static Future<void> joinBusinessByCode({
    required String inviteCode,
  }) async {
    await ApiClient.instance.post(
      '/businesses/join',
      data: {'inviteCode': inviteCode},
    );
  }

  /// Phase 12 §B: this is the single highest-leverage cache fix — every
  /// other read (units/buyers/bills/deposits/etc.) waits on
  /// currentBusinessProvider, which derives from this call. Before this
  /// fallback, a cold-start offline failed here first and never gave
  /// any of those other repositories' own caches a chance to run,
  /// surfacing a full-screen "कुछ गलत हुआ" error instead of the app.
  static Future<List<Business>> getUserBusinesses() async {
    return LocalCacheService.fetchListWithFallback<Business>(
      key: 'businesses:mine',
      fetch: () async {
        final response = await ApiClient.instance.get('/businesses/mine');
        return (response.data as List).map((b) => Business.fromJson(b)).toList();
      },
      toJson: (b) => b.toJson(),
      fromJson: Business.fromJson,
    );
  }

  /// Generates a fresh 5-minute, single-use invite code — call this right
  /// when the user taps "Share", not ahead of time.
  static Future<InviteCode> generateInviteCode(String businessId) async {
    final response = await ApiClient.instance.post('/businesses/$businessId/invite-code');
    return InviteCode.fromJson(response.data);
  }
}
