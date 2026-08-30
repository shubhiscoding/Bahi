import 'dart:async';
import '../../../core/models/inventory_item.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/socket_service.dart';

/// Inventory repository — calls the Node/Express backend. Every write
/// sets updated_by/updated_at server-side (hard requirement per §9),
/// enforced now in backend/src/services/inventoryService.ts.
class InventoryRepository {
  static String _cacheKey(String businessId) => 'items:$businessId';

  /// Live list of items for a business: initial REST fetch (falling back
  /// to the local cache if offline, design.md §9), then patched by
  /// Socket.IO events (item:created/updated/deleted) — replaces the old
  /// Supabase Realtime `.stream()`.
  static Stream<List<InventoryItem>> watchItems(String businessId) {
    final controller = StreamController<List<InventoryItem>>();
    List<InventoryItem> current = [];

    void emit() => controller.add(List.unmodifiable(current));

    Future<void> loadInitial() async {
      try {
        current = await _fetchItems(businessId);
        emit();
        // Cache the fresh list for the next offline read.
        await LocalCacheService.set(
          _cacheKey(businessId),
          current.map((i) => i.toJson()).toList(),
        );
      } catch (e) {
        // Offline (or backend unreachable) — fall back to the last
        // cached snapshot rather than showing an empty/error list.
        final cached = await LocalCacheService.get(_cacheKey(businessId));
        if (cached != null) {
          current = (cached as List)
              .map((json) => InventoryItem.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          emit();
        } else {
          rethrow;
        }
      }
    }

    final socket = SocketService.connect();
    SocketService.joinBusiness(businessId);

    // Every socket-driven change also re-caches the list, so the offline
    // snapshot stays current for as long as the app was online, not just
    // as of the last full page load.
    void recache() =>
        LocalCacheService.set(_cacheKey(businessId), current.map((i) => i.toJson()).toList());

    void onCreated(dynamic data) {
      final item = InventoryItem.fromJson(Map<String, dynamic>.from(data));
      current = [...current, item]..sort((a, b) => a.name.compareTo(b.name));
      emit();
      recache();
    }

    void onUpdated(dynamic data) {
      final item = InventoryItem.fromJson(Map<String, dynamic>.from(data));
      current = current.map((i) => i.id == item.id ? item : i).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      emit();
      recache();
    }

    void onDeleted(dynamic data) {
      final id = Map<String, dynamic>.from(data)['id'] as String;
      current = current.where((i) => i.id != id).toList();
      emit();
      recache();
    }

    socket.on('item:created', onCreated);
    socket.on('item:updated', onUpdated);
    socket.on('item:deleted', onDeleted);

    loadInitial();

    controller.onCancel = () {
      socket.off('item:created', onCreated);
      socket.off('item:updated', onUpdated);
      socket.off('item:deleted', onDeleted);
    };

    return controller.stream;
  }

  static Future<List<InventoryItem>> _fetchItems(String businessId) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/items');
    return (response.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }

  static Future<InventoryItem> createItem({
    required String businessId,
    required String name,
    required double price,
    required int quantity,
    required String unit,
  }) async {
    final response = await ApiClient.instance.post(
      '/businesses/$businessId/items',
      data: {'name': name, 'price': price, 'quantity': quantity, 'unit': unit},
    );
    return InventoryItem.fromJson(response.data);
  }

  static Future<InventoryItem> updateItem({
    required String businessId,
    required String itemId,
    required String name,
    required double price,
    required int quantity,
    required String unit,
  }) async {
    final response = await ApiClient.instance.put(
      '/businesses/$businessId/items/$itemId',
      data: {'name': name, 'price': price, 'quantity': quantity, 'unit': unit},
    );
    return InventoryItem.fromJson(response.data);
  }

  static Future<void> deleteItem({
    required String businessId,
    required String itemId,
  }) async {
    await ApiClient.instance.delete('/businesses/$businessId/items/$itemId');
  }
}
