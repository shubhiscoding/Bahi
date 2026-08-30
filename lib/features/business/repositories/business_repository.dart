import '../../../core/models/business.dart';
import '../../../core/services/supabase_client.dart';

/// Business repository — CRUD for businesses + business_members
class BusinessRepository {
  /// Create a new business and add the creator as owner
  /// Returns the business with generated invite_code
  static Future<Business> createBusiness({
    required String ownerId,
    required String businessName,
  }) async {
    try {
      // Generate a short, unique invite code (8 chars alphanumeric)
      final inviteCode = _generateInviteCode();

      final response = await SupabaseClientService.client
          .from('businesses')
          .insert({
            'name': businessName,
            'owner_id': ownerId,
            'invite_code': inviteCode,
          })
          .select()
          .single();

      final business = Business.fromJson(response);

      // Add owner to business_members
      await SupabaseClientService.client.from('business_members').insert({
        'business_id': business.id,
        'user_id': ownerId,
        'role': 'owner',
      });

      return business;
    } catch (e) {
      print('Error creating business: $e');
      rethrow;
    }
  }

  /// Join a business using an invite code
  static Future<void> joinBusinessByCode({
    required String userId,
    required String inviteCode,
  }) async {
    try {
      // Look up the business by invite code
      final businesses = await SupabaseClientService.client
          .from('businesses')
          .select()
          .eq('invite_code', inviteCode);

      if (businesses.isEmpty) {
        throw Exception('Invite code not found');
      }

      final businessId = businesses[0]['id'];

      // Add user as member
      await SupabaseClientService.client.from('business_members').insert({
        'business_id': businessId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      print('Error joining business: $e');
      rethrow;
    }
  }

  /// Get all businesses for a user
  static Future<List<Business>> getUserBusinesses(String userId) async {
    try {
      final memberships = await SupabaseClientService.client
          .from('business_members')
          .select('businesses(*)')
          .eq('user_id', userId);

      return memberships
          .map((m) => Business.fromJson(m['businesses']))
          .toList();
    } catch (e) {
      print('Error fetching businesses: $e');
      rethrow;
    }
  }

  /// Generate a short, random invite code
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = List.generate(8, (i) {
      final idx = (DateTime.now().microsecond + i) % chars.length;
      return chars[idx];
    }).join();
    return random;
  }
}
