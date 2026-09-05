import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/offline_guard.dart';
import '../../../core/widgets/field_with_mic.dart';
import '../providers/inventory_providers.dart';
import '../widgets/unit_picker.dart';
import '../../team/providers/team_providers.dart';

/// Add/Edit Item Screen (design.md §5)
/// Voice-first fields (rule 1: mic → listen → confirm both visually and
/// audibly), with typing as fallback.
class AddEditItemScreen extends ConsumerStatefulWidget {
  final InventoryItem? item; // null = create, set = edit

  const AddEditItemScreen({super.key, this.item});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late String _selectedUnit;
  bool _isSaving = false;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(
      text: widget.item != null ? widget.item!.price.toStringAsFixed(0) : '',
    );
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '',
    );
    _selectedUnit = widget.item?.unit ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!await ensureOnline(context)) return;

    // Name is only ever taken from the field when creating — set once at
    // creation, intentionally not editable afterward (confirmed
    // decision). In edit mode the field isn't even shown; always send
    // the item's existing, unchanged name through (the backend also
    // ignores any name it's sent on update, so this is belt-and-braces,
    // not the only thing enforcing it).
    final name = isEditing ? widget.item!.name : _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty || priceText.isEmpty || quantityText.isEmpty || _selectedUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सारी जानकारी भरें')),
      );
      return;
    }

    final price = double.tryParse(priceText);
    final quantity = int.tryParse(quantityText);
    if (price == null || quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सही नंबर डालें')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(
        saveItemProvider(
          ItemFormInput(
            itemId: widget.item?.id,
            name: name,
            price: price,
            quantity: quantity,
            unit: _selectedUnit,
          ),
        ).future,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (!await ensureOnline(context)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${Strings.deleteItem}?'),
        content: Text('${widget.item!.name} हटाएँ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              Strings.deleteItem,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(deleteItemProvider(widget.item!.id).future);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Backend maps the onDelete: Restrict FK failure (item has been
      // billed before) to 409 { error: 'ITEM_HAS_BILLS' } specifically
      // so this can show a real sentence instead of a raw/opaque error
      // — the exact bug reported after this screen shipped.
      final isItemHasBills =
          e is DioException && e.response?.data?['error'] == 'ITEM_HAS_BILLS';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isItemHasBills ? Strings.itemHasBills : 'त्रुटि: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isOwner = roleAsync.value == 'owner';
    // design.md rule 5: disabled (greyed out), never hidden, when offline
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? Strings.editItem : Strings.addItem),
        centerTitle: true,
        actions: [
          // Owner-only delete (design.md: secondary/rare action, smaller, per rule 6)
          if (isEditing && isOwner)
            IconButton(
              onPressed: isOnline ? _handleDelete : null,
              icon: Icon(
                Icons.delete_outline,
                color: isOnline ? AppColors.danger : AppColors.inkSoft,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name: editable only at creation (voice-first, per
              // design.md rule 1). Set once and intentionally not
              // editable afterward (confirmed decision) — shown as a
              // plain read-only label in edit mode instead, so the
              // screen still shows what item this is without offering a
              // field that can't actually be saved.
              if (isEditing) ...[
                Text(Strings.itemName, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  widget.item!.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                ),
              ] else
                FieldWithMic(
                  label: Strings.itemName,
                  controller: _nameController,
                  keyboardType: TextInputType.text,
                ),
              const SizedBox(height: 20),

              // Quantity field
              FieldWithMic(
                label: Strings.itemQuantity,
                controller: _quantityController,
                keyboardType: TextInputType.number,
                isNumeric: true,
              ),
              const SizedBox(height: 20),

              // Price field
              FieldWithMic(
                label: Strings.itemPrice,
                controller: _priceController,
                keyboardType: TextInputType.number,
                prefixText: '₹ ',
                isNumeric: true,
              ),
              const SizedBox(height: 20),

              // Unit selector — searchable per-business list + add-new
              // affordance (design.md rule 9: tap over typing)
              UnitPicker(
                selectedUnit: _selectedUnit,
                onSelected: (unit) => setState(() => _selectedUnit = unit),
              ),

              const SizedBox(height: 32),

              // Primary action: Save (design.md rule 6)
              ElevatedButton(
                onPressed: (_isSaving || !isOnline) ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        Strings.saveItem,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
              ),

              if (!isOnline) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text(
                      Strings.connectToInternet,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.danger,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
