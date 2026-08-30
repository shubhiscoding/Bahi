import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/offline_guard.dart';
import '../../../core/widgets/voice_confirm_sheet.dart';
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

    final name = _nameController.text.trim();
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
              // Name field (voice-first, per design.md rule 1)
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
                isNumeric: true,
              ),
              const SizedBox(height: 20),

              // Price field
              _FieldWithMic(
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

/// A text field with a mic button (design.md rule 1: voice is the primary
/// input, typing is the fallback — mic is the largest, most dominant
/// control on this row).
class _FieldWithMic extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefixText;
  final bool isNumeric;

  const _FieldWithMic({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.prefixText,
    this.isNumeric = false,
  });

  Future<void> _handleMicTap(BuildContext context) async {
    final heardText = await showVoiceInputSheet(context, fieldLabel: label);
    if (heardText == null) return;

    if (isNumeric) {
      // Best-effort: pull digits out of the recognized speech. Spoken
      // Hindi number words (e.g. "पांच सौ") aren't parsed — the digit
      // extraction covers the common case where the recognizer already
      // returns numerals, and the field remains editable either way.
      final digits = RegExp(r'\d+').firstMatch(heardText)?.group(0);
      controller.text = digits ?? heardText;
    } else {
      controller.text = heardText;
    }
  }

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
            // Mic button — largest, most dominant control (rule 1)
            InkWell(
              onTap: () => _handleMicTap(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 8),
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
          ],
        ),
      ],
    );
  }
}
