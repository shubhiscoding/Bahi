import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/price_history_point.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/inventory_repository.dart';

/// Live stream of inventory items for the current business (REST fetch +
/// Socket.IO patches — see InventoryRepository.watchItems)
final inventoryItemsProvider = StreamProvider<List<InventoryItem>>((ref) {
  final businessAsync = ref.watch(currentBusinessProvider);

  return businessAsync.when(
    data: (business) {
      if (business == null) return Stream.value(<InventoryItem>[]);
      return InventoryRepository.watchItems(business.id);
    },
    loading: () => Stream.value(<InventoryItem>[]),
    error: (err, stack) => Stream.value(<InventoryItem>[]),
  );
});

/// Input for creating/updating an item
class ItemFormInput {
  final String? itemId; // null for create, set for update
  final String name;
  final double price;
  final int quantity;
  final String unit;

  ItemFormInput({
    this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
  });
}

/// Save an item (create or update depending on itemId).
/// updated_by/updated_at are stamped server-side now — the backend derives
/// the acting user from the JWT, not a client-supplied value.
final saveItemProvider =
    FutureProvider.autoDispose.family<InventoryItem, ItemFormInput>((ref, input) async {
  final authState = await ref.watch(authSessionProvider.future);
  if (authState.user == null) throw Exception('Not authenticated');

  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  if (input.itemId == null) {
    return InventoryRepository.createItem(
      businessId: business.id,
      name: input.name,
      price: input.price,
      quantity: input.quantity,
      unit: input.unit,
    );
  } else {
    return InventoryRepository.updateItem(
      businessId: business.id,
      itemId: input.itemId!,
      name: input.name,
      price: input.price,
      quantity: input.quantity,
      unit: input.unit,
    );
  }
});

/// Delete an item (owner-only, enforced by backend middleware)
final deleteItemProvider =
    FutureProvider.autoDispose.family<void, String>((ref, itemId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  await InventoryRepository.deleteItem(businessId: business.id, itemId: itemId);
});

/// Full price history for an item, ascending — feeds the price-tracker
/// chart on the item detail screen (Phase 7 §A/§B).
final priceHistoryProvider =
    FutureProvider.autoDispose.family<List<PriceHistoryPoint>, String>((ref, itemId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return InventoryRepository.fetchPriceHistory(businessId: business.id, itemId: itemId);
});
