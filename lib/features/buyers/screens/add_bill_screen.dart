import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/buyer.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/offline_guard.dart';
import '../../../core/widgets/field_with_mic.dart';
import '../providers/bill_providers.dart';
import '../repositories/bill_repository.dart';
import '../widgets/bill_item_picker.dart';
import '../widgets/buyer_picker.dart';

enum _PaymentChoice { unpaid, partial, paid }

/// One product line on the bill-creation form (Phase 8 §F, revised).
/// isExpanded controls whether the item picker (search+list) is showing
/// or the line has collapsed to a compact name+qty+price summary.
class _BillLineState {
  InventoryItem? item;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool isExpanded = true;

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }
}

/// Add-bill screen — sold-to buyer picker, repeatable product lines
/// (item + qty + price, price defaulted from the item but editable), date
/// (defaults today, editable), and a 3-way payment choice (unpaid /
/// partial / paid in full, defaults unpaid) — partial shows an amount
/// field and records that payment right after the bill is created.
class AddBillScreen extends ConsumerStatefulWidget {
  const AddBillScreen({super.key});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  Buyer? _selectedBuyer;
  // Starts empty — only the "उत्पाद जोड़ें" button shows until the first
  // tap (revised spec: no picker visible before the user asks for one).
  final List<_BillLineState> _lines = [];
  DateTime _billDate = DateTime.now();
  // No default — required, but the shopkeeper must explicitly pick one
  // rather than silently inheriting "unpaid" or any other default.
  _PaymentChoice? _paymentChoice;
  final _partialAmountController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _partialAmountController.dispose();
    super.dispose();
  }

  void _addLine() {
    setState(() {
      // Only one line's picker is ever expanded at a time. Any existing
      // line with no item picked yet is discarded rather than collapsed
      // — an empty collapsed row would have nothing to show; the ones
      // that already have an item collapse to their summary as usual.
      _lines.removeWhere((line) {
        if (line.item == null) {
          line.dispose();
          return true;
        }
        line.isExpanded = false;
        return false;
      });
      _lines.add(_BillLineState());
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _handleSave() async {
    if (!await ensureOnline(context)) return;

    if (_selectedBuyer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('खरीदार चुनें')),
      );
      return;
    }

    final lineInputs = <BillLineInput>[];
    for (final line in _lines) {
      if (line.item == null) continue;
      final quantity = int.tryParse(line.quantityController.text.trim());
      final price = double.tryParse(line.priceController.text.trim());
      if (quantity == null || quantity <= 0 || price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सही संख्या और कीमत डालें')),
        );
        return;
      }
      lineInputs.add(BillLineInput(itemId: line.item!.id, quantity: quantity, price: price));
    }

    if (lineInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कम से कम एक उत्पाद जोड़ें')),
      );
      return;
    }

    if (_paymentChoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('भुगतान की स्थिति चुनें')),
      );
      return;
    }

    final total = lineInputs.fold<double>(0, (sum, l) => sum + l.quantity * l.price);
    double? partialAmount;
    if (_paymentChoice == _PaymentChoice.partial) {
      partialAmount = double.tryParse(_partialAmountController.text.trim());
      if (partialAmount == null || partialAmount <= 0 || partialAmount > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सही भुगतान राशि डालें (कुल से ज़्यादा नहीं)')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final bill = await ref.read(
        createBillProvider(
          CreateBillInput(
            buyerId: _selectedBuyer!.id,
            billDate: _billDate,
            items: lineInputs,
            markPaidNow: _paymentChoice == _PaymentChoice.paid,
          ),
        ).future,
      );

      // The create endpoint only supports "fully paid now or not at all"
      // — a partial payment is recorded as a second call right after,
      // reusing the same addPayment path the bill-detail screen's
      // "record payment" action already goes through. If this second
      // call fails, the bill itself still exists (unpaid) — recoverable
      // from the bill detail screen, so it's not rolled back.
      if (partialAmount != null) {
        try {
          await ref.read(addPaymentProvider((billId: bill.id, amount: partialAmount)).future);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('बिल बन गया, पर भुगतान दर्ज नहीं हुआ: ${e.toString()}')),
            );
          }
        }
      }

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

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(Strings.createBill), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BuyerPicker(
                selectedBuyer: _selectedBuyer,
                onSelected: (buyer) => setState(() => _selectedBuyer = buyer),
              ),
              const SizedBox(height: 24),

              // No header/picker at all until the first tap — per spec,
              // initially only the add-product button should be visible.
              if (_lines.isNotEmpty) ...[
                Text(Strings.addProduct, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
              ],

              for (var i = 0; i < _lines.length; i++) ...[
                _BillLineCard(
                  line: _lines[i],
                  // Items already picked on the OTHER lines — excluded
                  // from this line's picker so the same item can't be
                  // added twice on one bill.
                  excludeItemIds: {
                    for (final other in _lines)
                      if (other != _lines[i] && other.item != null) other.item!.id,
                  },
                  onChanged: () => setState(() {}),
                  onExpand: () => setState(() {
                    for (final line in _lines) {
                      line.isExpanded = false;
                    }
                    _lines[i].isExpanded = true;
                  }),
                  onRemove: () => _removeLine(i),
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add, size: 22),
                label: Text(_lines.isEmpty ? Strings.addProduct : Strings.addAnotherProduct),
              ),
              const SizedBox(height: 24),

              Text(Strings.billDate, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: AppColors.inkSoft),
                      const SizedBox(width: 12),
                      Text(
                        '${_billDate.day}/${_billDate.month}/${_billDate.year}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _PaidToggleOption(
                      label: Strings.unpaid,
                      isSelected: _paymentChoice == _PaymentChoice.unpaid,
                      onTap: () => setState(() => _paymentChoice = _PaymentChoice.unpaid),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaidToggleOption(
                      label: Strings.partialPayment,
                      isSelected: _paymentChoice == _PaymentChoice.partial,
                      onTap: () => setState(() => _paymentChoice = _PaymentChoice.partial),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaidToggleOption(
                      label: Strings.paid,
                      isSelected: _paymentChoice == _PaymentChoice.paid,
                      onTap: () => setState(() => _paymentChoice = _PaymentChoice.paid),
                    ),
                  ),
                ],
              ),
              if (_paymentChoice == _PaymentChoice.partial) ...[
                const SizedBox(height: 16),
                FieldWithMic(
                  label: Strings.paymentAmount,
                  controller: _partialAmountController,
                  keyboardType: TextInputType.number,
                  prefixText: '₹ ',
                  isNumeric: true,
                ),
              ],
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: (_isSaving || !isOnline) ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(Strings.createBill, style: Theme.of(context).textTheme.labelLarge),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
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

/// A product line — expanded shows the item picker only (no qty/price
/// yet); collapsed shows a compact tappable "item name" row (tap to
/// re-expand and change it) plus the qty/price fields, which stay
/// editable regardless of expand state. Mutually exclusive with the
/// picker per the revised spec: only one of {picker, qty/price fields}
/// is visible at a time for a given line.
class _BillLineCard extends StatelessWidget {
  final _BillLineState line;
  final Set<String> excludeItemIds;
  final VoidCallback onChanged;
  final VoidCallback onExpand;
  final VoidCallback onRemove;

  const _BillLineCard({
    required this.line,
    required this.excludeItemIds,
    required this.onChanged,
    required this.onExpand,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: line.isExpanded
                    ? BillItemPicker(
                        selectedItem: line.item,
                        excludeItemIds: excludeItemIds,
                        onSelected: (item) {
                          line.item = item;
                          // Default the price from the item's current
                          // price — spec requirement — but only if the
                          // user hasn't already typed something, so
                          // re-picking doesn't clobber an edit.
                          if (line.priceController.text.trim().isEmpty) {
                            line.priceController.text = item.price.toStringAsFixed(0);
                          }
                          line.isExpanded = false; // collapse on selection
                          onChanged();
                        },
                      )
                    : _CollapsedItemRow(
                        name: line.item?.name ?? '',
                        onTap: onExpand,
                      ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, color: AppColors.danger, size: 22),
              ),
            ],
          ),
          if (!line.isExpanded && line.item != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FieldWithMic(
                    label: Strings.itemQuantity,
                    controller: line.quantityController,
                    keyboardType: TextInputType.number,
                    isNumeric: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FieldWithMic(
                    label: Strings.itemPrice,
                    controller: line.priceController,
                    keyboardType: TextInputType.number,
                    prefixText: '₹ ',
                    isNumeric: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsedItemRow extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _CollapsedItemRow({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.expand_more, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _PaidToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaidToggleOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.inkPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
