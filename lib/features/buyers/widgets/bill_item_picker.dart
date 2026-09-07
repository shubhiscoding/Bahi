import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/search_match.dart';
import '../../../core/widgets/mic_search_field.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../inventory/screens/add_edit_item_screen.dart';

/// Item picker for a bill line (Phase 8 §F, Phase 14 revised) — existing
/// inventory items, plus a "+ नया सामान जोड़ें" row that opens the full
/// item-creation screen. Same search+scroll shape as BuyerPicker (including
/// the always-present trailing add-new row even on empty search).
///
/// Deliberately does NOT filter out items with quantity 0 — a shopkeeper
/// may still want to bill something that's out of stock (e.g. on
/// backorder), so it must stay pickable, not hidden.
class BillItemPicker extends ConsumerStatefulWidget {
  final InventoryItem? selectedItem;
  final ValueChanged<InventoryItem> onSelected;

  const BillItemPicker({
    super.key,
    required this.selectedItem,
    required this.onSelected,
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

  Future<void> _handleAddNew() async {
    final created = await Navigator.of(context).push<InventoryItem>(
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
    if (created != null) widget.onSelected(created);
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
            // Same item can be added on more than one line in a bill —
            // no longer excluding items already picked elsewhere in this
            // bill (previous behavior, since removed).
            final filtered = _searchQuery.isEmpty
                ? items
                : items.where((i) => matchesSearch(i.name, _searchQuery)).toList();
            final showNoResults = filtered.isEmpty && _searchQuery.isNotEmpty;

            // Bounded height so ~4 rows show by default; the rest of the
            // list (and the add-new row) is one scroll away — same shape as
            // BuyerPicker. The add-new row is always the last child, never
            // conditionally omitted.
            return Container(
              constraints: const BoxConstraints(maxHeight: 4.5 * 56),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in filtered) ...[
                    InkWell(
                      onTap: () => widget.onSelected(item),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: widget.selectedItem?.id == item.id ? AppColors.primarySoft : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: widget.selectedItem?.id == item.id
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                              ),
                            ),
                            Text(
                              '₹${item.price.toStringAsFixed(0)} / ${item.unit}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                            ),
                            if (widget.selectedItem?.id == item.id) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.border),
                  ],
                  if (showNoResults) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        Strings.noProductsFound,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.border),
                  ],
                  _AddNewProductRow(onTap: _handleAddNew),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Visually distinct from item rows (accent-tinted background + bold add
/// icon) — always present at the bottom of the list, matching BuyerPicker's
/// pattern. Tapping opens the full add-item screen (create new inventory).
class _AddNewProductRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewProductRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.accentSoft,
        child: Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Text(
              Strings.addNewProduct,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.inkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
