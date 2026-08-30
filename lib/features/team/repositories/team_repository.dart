import 'dart:async';
import '../../../core/models/business.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/socket_service.dart';

/// Team repository — calls the Node/Express backend. GET /members already
/// joins profile names server-side, so no separate profile lookup is
/// needed here (unlike the old Supabase Realtime .stream() version, which
/// couldn't do embedded joins).
class TeamRepository {
  /// Live list of members for a business: initial REST fetch, then
  /// patched by Socket.IO events (member:added/removed).
  static Stream<List<BusinessMember>> watchMembers(String businessId) {
    final controller = StreamController<List<BusinessMember>>();
    List<BusinessMember> current = [];

    void emit() => controller.add(List.unmodifiable(current));

    Future<void> loadInitial() async {
      current = await _fetchMembers(businessId);
      emit();
    }

    final socket = SocketService.connect();
    SocketService.joinBusiness(businessId);

    // member:added/removed only carry a partial payload (userId, fullName),
    // so simplest correct behavior is to refetch the full list on either event.
    void onMemberChanged(dynamic _) => loadInitial();

    socket.on('member:added', onMemberChanged);
    socket.on('member:removed', onMemberChanged);

    loadInitial();

    controller.onCancel = () {
      socket.off('member:added', onMemberChanged);
      socket.off('member:removed', onMemberChanged);
    };

    return controller.stream;
  }

  static Future<List<BusinessMember>> _fetchMembers(String businessId) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/members');
    return (response.data as List).map((m) => BusinessMember.fromJson(m)).toList();
  }

  /// Fetch the current user's role in a business (used for owner-only gating)
  static Future<String?> getUserRole({
    required String businessId,
    required String userId,
  }) async {
    final members = await _fetchMembers(businessId);
    final me = members.where((m) => m.userId == userId).firstOrNull;
    return me?.role;
  }

  /// Remove a member (owner-only, enforced by backend middleware)
  static Future<void> removeMember({
    required String businessId,
    required String userId,
  }) async {
    await ApiClient.instance.delete('/businesses/$businessId/members/$userId');
  }
}
