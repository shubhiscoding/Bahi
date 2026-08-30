import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/inventory_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/inventory_repository.dart';

/// Realtime stream of inventory items for the current business
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

/// Save an item (create or update depending on itemId)
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
      updatedBy: authState.user!.id,
    );
  } else {
    return InventoryRepository.updateItem(
      itemId: input.itemId!,
      name: input.name,
      price: input.price,
      quantity: input.quantity,
      unit: input.unit,
      updatedBy: authState.user!.id,
    );
  }
});

/// Delete an item (owner-only, enforced by RLS)
final deleteItemProvider =
    FutureProvider.autoDispose.family<void, String>((ref, itemId) async {
  await InventoryRepository.deleteItem(itemId);
});
