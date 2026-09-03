import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/mic_search_field.dart';
import '../../inventory/providers/inventory_providers.dart';

/// Item picker for a bill line (Phase 8 §F) — existing inventory items
/// only, no inline "add new" (creating a whole new item mid-bill is out
/// of scope; that's what the Inventory tab is for). Same search+scroll
/// shape as BuyerPicker, minus the add-new row.
///
/// Deliberately does NOT filter out items with quantity 0 — a shopkeeper
/// may still want to bill something that's out of stock (e.g. on
/// backorder), so it must stay pickable, not hidden.
class BillItemPicker extends ConsumerStatefulWidget {
  final InventoryItem? selectedItem;
  final ValueChanged<InventoryItem> onSelected;
  // Items already picked on OTHER lines of the same bill — excluded here
  // so the same item can't be added twice; this line's own current
  // selection is never excluded from itself.
  final Set<String> excludeItemIds;

  const BillItemPicker({
    super.key,
    required this.selectedItem,
    required this.onSelected,
    this.excludeItemIds = const {},
  });

  @override
  ConsumerState<BillItemPicker> createState() => _BillItemPickerState();
}

class _BillItemPickerState extends ConsumerState<BillItemPicker> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicSearchField(
          controller: _searchController,
          hintText: 'सामान खोजें',
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 8),
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (err, stack) => Text('सामान लोड नहीं हो सका', style: TextStyle(color: AppColors.danger)),
          data: (items) {
            final available = items.where((i) => !widget.excludeItemIds.contains(i.id));
            final filtered = _searchQuery.isEmpty
                ? available.toList()
                : available
                    .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'कुछ नहीं मिला',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              );
            }

            return Container(
              constraints: const BoxConstraints(maxHeight: 4.5 * 56),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, index) => Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final isSelected = widget.selectedItem?.id == item.id;
                  return InkWell(
                    onTap: () => widget.onSelected(item),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: isSelected ? AppColors.primarySoft : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                            ),
                          ),
                          Text(
                            '₹${item.price.toStringAsFixed(0)} / ${item.unit}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkSoft,
                                ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
