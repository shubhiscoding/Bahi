import 'dart:async';
import '../../../core/models/inventory_item.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/socket_service.dart';

/// Inventory repository — calls the Node/Express backend. Every write
/// sets updated_by/updated_at server-side (hard requirement per §9),
/// enforced now in backend/src/services/inventoryService.ts.
class InventoryRepository {
  /// Live list of items for a business: initial REST fetch, then patched
  /// by Socket.IO events (item:created/updated/deleted) — replaces the
  /// old Supabase Realtime `.stream()`.
  static Stream<List<InventoryItem>> watchItems(String businessId) {
    final controller = StreamController<List<InventoryItem>>();
    List<InventoryItem> current = [];

    void emit() => controller.add(List.unmodifiable(current));

    Future<void> loadInitial() async {
      current = await _fetchItems(businessId);
      emit();
    }

    final socket = SocketService.connect();
    SocketService.joinBusiness(businessId);

    void onCreated(dynamic data) {
      final item = InventoryItem.fromJson(Map<String, dynamic>.from(data));
      current = [...current, item]..sort((a, b) => a.name.compareTo(b.name));
      emit();
    }

    void onUpdated(dynamic data) {
      final item = InventoryItem.fromJson(Map<String, dynamic>.from(data));
      current = current.map((i) => i.id == item.id ? item : i).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      emit();
    }

    void onDeleted(dynamic data) {
      final id = Map<String, dynamic>.from(data)['id'] as String;
      current = current.where((i) => i.id != id).toList();
      emit();
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
