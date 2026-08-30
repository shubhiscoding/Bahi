import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/theme/colors.dart';
import '../providers/inventory_providers.dart';
import '../../team/providers/team_providers.dart';

const _units = [
  Strings.unitPiece,
  Strings.unitKg,
  Strings.unitLitre,
  Strings.unitDozen,
  Strings.unitMetre,
  Strings.unitBox,
  Strings.unitBottle,
  Strings.unitBag,
];

/// Add/Edit Item Screen (design.md §5)
/// Typed fields for now; mic buttons present but disabled until voice
/// input is wired in a later pass (design.md rule 1, deferred per plan §N).
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
    _selectedUnit = widget.item?.unit ?? _units[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty || priceText.isEmpty || quantityText.isEmpty) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isOwner = roleAsync.value == 'owner';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? Strings.editItem : Strings.addItem),
        centerTitle: true,
        actions: [
          // Owner-only delete (design.md: secondary/rare action, smaller, per rule 6)
          if (isEditing && isOwner)
            IconButton(
              onPressed: _handleDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field (mic-ready layout — mic wiring deferred, rule 1)
              _FieldWithMic(
                label: Strings.itemName,
                controller: _nameController,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 20),

              // Quantity field
              _FieldWithMic(
                label: Strings.itemQuantity,
                controller: _quantityController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // Price field
              _FieldWithMic(
                label: Strings.itemPrice,
                controller: _priceController,
                keyboardType: TextInputType.number,
                prefixText: '₹ ',
              ),
              const SizedBox(height: 20),

              // Unit selector (chip-based, per design.md rule 9: tap over typing)
              Text(Strings.itemUnit, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _units.map((unit) {
                  final isSelected = _selectedUnit == unit;
                  return ChoiceChip(
                    label: Text(unit),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedUnit = unit),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.inkPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Primary action: Save (design.md rule 6)
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field with a disabled mic button placeholder (design.md rule 1:
/// mic-first layout, wiring deferred to a later pass — see plan §N).
class _FieldWithMic extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefixText;

  const _FieldWithMic({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  prefixText: prefixText,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mic button placeholder — disabled until voice input is wired (plan §N)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.mic_off, color: AppColors.inkSoft, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}
