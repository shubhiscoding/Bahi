import 'dart:async';
import '../../../core/models/buyer.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/socket_service.dart';

/// Buyer repository — same fetch+socket-patch+offline-cache pattern as
/// InventoryRepository.watchItems (Phase 8 §C, cloned from Phase 4/7's
/// established shape).
class BuyerRepository {
  static String _cacheKey(String businessId) => 'buyers:$businessId';

  static Stream<List<Buyer>> watchBuyers(String businessId) {
    final controller = StreamController<List<Buyer>>();
    List<Buyer> current = [];

    void emit() => controller.add(List.unmodifiable(current));

    Future<void> loadInitial() async {
      try {
        current = await _fetchBuyers(businessId);
        emit();
        await LocalCacheService.set(
          _cacheKey(businessId),
          current.map((b) => _toJson(b)).toList(),
        );
      } catch (e) {
        final cached = await LocalCacheService.get(_cacheKey(businessId));
        if (cached != null) {
          current = (cached as List)
              .map((json) => Buyer.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          emit();
        } else {
          rethrow;
        }
      }
    }

    final socket = SocketService.connect();
    SocketService.joinBusiness(businessId);

    void onCreated(dynamic data) {
      final buyer = Buyer.fromJson(Map<String, dynamic>.from(data));
      current = [...current, buyer];
      emit();
      LocalCacheService.set(_cacheKey(businessId), current.map((b) => _toJson(b)).toList());
    }

    socket.on('buyer:created', onCreated);

    loadInitial();

    controller.onCancel = () {
      socket.off('buyer:created', onCreated);
    };

    return controller.stream;
  }

  static Map<String, dynamic> _toJson(Buyer b) => {
        'id': b.id,
        'name': b.name,
        'createdAt': b.createdAt.toIso8601String(),
        'lastBilledAt': b.lastBilledAt?.toIso8601String(),
      };

  static Future<List<Buyer>> _fetchBuyers(String businessId) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/buyers');
    return (response.data as List).map((b) => Buyer.fromJson(b)).toList();
  }

  static Future<Buyer> createBuyer({required String businessId, required String name}) async {
    final response = await ApiClient.instance.post(
      '/businesses/$businessId/buyers',
      data: {'name': name},
    );
    return Buyer.fromJson(response.data);
  }

  static Future<BuyerDetail> fetchBuyerDetail({
    required String businessId,
    required String buyerId,
  }) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/buyers/$buyerId');
    return BuyerDetail.fromJson(response.data);
  }
}
