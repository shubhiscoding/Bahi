import '../../../core/services/supabase_client.dart';

/// A raw business_members row (no join — Realtime .stream() doesn't support embeds)
class TeamMemberRow {
  final String userId;
  final String businessId;
  final String role; // 'owner' | 'member'
  final DateTime joinedAt;

  TeamMemberRow({
    required this.userId,
    required this.businessId,
    required this.role,
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory TeamMemberRow.fromJson(Map<String, dynamic> json) {
    return TeamMemberRow(
      userId: json['user_id'] ?? '',
      businessId: json['business_id'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }
}

/// A member row joined with their profile's full name, for display.
class TeamMember {
  final TeamMemberRow row;
  final String fullName;

  TeamMember({required this.row, required this.fullName});

  String get userId => row.userId;
  String get role => row.role;
  bool get isOwner => row.isOwner;
  DateTime get joinedAt => row.joinedAt;
}

/// Team repository — member list + remove (owner-only)
class TeamRepository {
  /// Stream of raw member rows for a business (no profile join — joined
  /// client-side in the provider layer since Realtime .stream() doesn't
  /// support embedded selects).
  static Stream<List<TeamMemberRow>> watchMemberRows(String businessId) {
    return SupabaseClientService.client
        .from('business_members')
        .stream(primaryKey: ['business_id', 'user_id'])
        .eq('business_id', businessId)
        .map((rows) => rows.map((r) => TeamMemberRow.fromJson(r)).toList());
  }

  /// Fetch full_name for a set of user IDs
  static Future<Map<String, String>> fetchProfileNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final response = await SupabaseClientService.client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', userIds);

    final map = <String, String>{};
    for (final row in response) {
      map[row['id']] = row['full_name'] ?? '?';
    }
    return map;
  }

  /// Fetch the current user's role in a business (used for owner-only gating)
  static Future<String?> getUserRole({
    required String businessId,
    required String userId,
  }) async {
    try {
      final response = await SupabaseClientService.client
          .from('business_members')
          .select('role')
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .single();
      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Remove a member (owner-only — enforced by RLS server-side too)
  static Future<void> removeMember({
    required String businessId,
    required String userId,
  }) async {
    await SupabaseClientService.client
        .from('business_members')
        .delete()
        .eq('business_id', businessId)
        .eq('user_id', userId);
  }
}
