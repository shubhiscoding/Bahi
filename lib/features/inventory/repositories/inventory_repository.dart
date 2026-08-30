import '../../../core/models/inventory_item.dart';
import '../../../core/services/supabase_client.dart';

/// Inventory repository — CRUD for inventory_items.
/// Every write sets updated_by/updated_at (hard requirement per design.md §9 offline plan).
class InventoryRepository {
  /// Stream of items for a business, ordered by name.
  /// Used to feed a Riverpod StreamProvider for Realtime updates.
  static Stream<List<InventoryItem>> watchItems(String businessId) {
    return SupabaseClientService.client
        .from('inventory_items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('name')
        .map((rows) => rows.map((r) => InventoryItem.fromJson(r)).toList());
  }

  /// Create a new item
  static Future<InventoryItem> createItem({
    required String businessId,
    required String name,
    required double price,
    required int quantity,
    required String unit,
    required String updatedBy,
  }) async {
    final response = await SupabaseClientService.client
        .from('inventory_items')
        .insert({
          'business_id': businessId,
          'name': name,
          'price': price,
          'quantity': quantity,
          'unit': unit,
          'updated_by': updatedBy,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return InventoryItem.fromJson(response);
  }

  /// Update an existing item — always re-stamps updated_by/updated_at
  static Future<InventoryItem> updateItem({
    required String itemId,
    required String name,
    required double price,
    required int quantity,
    required String unit,
    required String updatedBy,
  }) async {
    final response = await SupabaseClientService.client
        .from('inventory_items')
        .update({
          'name': name,
          'price': price,
          'quantity': quantity,
          'unit': unit,
          'updated_by': updatedBy,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId)
        .select()
        .single();

    return InventoryItem.fromJson(response);
  }

  /// Delete an item (owner-only — enforced by RLS server-side too)
  static Future<void> deleteItem(String itemId) async {
    await SupabaseClientService.client.from('inventory_items').delete().eq('id', itemId);
  }
}
