import '../../../core/models/business.dart';
import '../../../core/services/api_client.dart';

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

  static Future<List<Business>> getUserBusinesses() async {
    final response = await ApiClient.instance.get('/businesses/mine');
    return (response.data as List).map((b) => Business.fromJson(b)).toList();
  }
}
