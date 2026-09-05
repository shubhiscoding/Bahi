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

/// A product line's UI state (revised — was a single isExpanded bool):
/// - [picking]: item search/list showing, no qty/price yet.
/// - [editing]: item chosen, its name shown as a compact tappable header
///   (tap to reopen the picker and change it) with qty/price fields
///   below, fully editable — this is the "currently being added" state.
/// - [summary]: fully collapsed to one compact read-only row (name, qty,
///   price) — only entered once "add more" moves a completed line out
///   of the way, or another line is reopened for editing. Tap to return
///   to [editing].
enum _LineMode { picking, editing, summary }

/// One product line on the bill-creation form (Phase 8 §F, revised).
class _BillLineState {
  InventoryItem? item;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  _LineMode mode = _LineMode.picking;

  /// Item picked + a valid positive quantity + a valid non-negative
  /// price — used to gate the "add more" button (can't add another line
  /// while this one is still unfinished).
  bool get isComplete {
    if (item == null) return false;
    final quantity = int.tryParse(quantityController.text.trim());
    final price = double.tryParse(priceController.text.trim());
    return quantity != null && quantity > 0 && price != null && price >= 0;
  }

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
  // Pre-selects the buyer picker (collapsed, not the expanded
  // search+list) when opened from that buyer's own detail page — the
  // shopkeeper is already looking at that buyer, no need to search for
  // them again.
  final Buyer? initialBuyer;

  const AddBillScreen({super.key, this.initialBuyer});

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
  void initState() {
    super.initState();
    _selectedBuyer = widget.initialBuyer;
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _partialAmountController.dispose();
    super.dispose();
  }

  /// Gates the "add more" button — can't add another line while the
  /// currently open one is still unfinished. Since only one line is ever
  /// non-summary at a time (see _addLine/_reopenLine), this reduces to
  /// "is the currently active line done", but checking every line is
  /// simplest and stays correct even in edge cases.
  bool get _canAddLine => _lines.every((line) => line.isComplete);

  void _addLine() {
    setState(() {
      // Defensive cleanup — the button is disabled until every line is
      // complete, so this should be a no-op in practice, not the thing
      // actually enforcing it.
      _lines.removeWhere((line) {
        if (line.item == null) {
          line.dispose();
          return true;
        }
        return false;
      });
      // Every existing (now-complete) line collapses to its one-row
      // summary — only the newly added line stays open.
      for (final line in _lines) {
        line.mode = _LineMode.summary;
      }
      _lines.add(_newLine());
    });
  }

  /// Live-updates _canAddLine (and thus the "add more" button's enabled
  /// state) as the user types, since plain text-field input otherwise
  /// wouldn't trigger a rebuild of this screen.
  _BillLineState _newLine() {
    final line = _BillLineState();
    line.quantityController.addListener(() => setState(() {}));
    line.priceController.addListener(() => setState(() {}));
    return line;
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
                  onChanged: () => setState(() {}),
                  // Tapping a fully-collapsed summary row reopens it for
                  // editing; every other line (already complete, per
                  // _canAddLine) collapses to its own summary.
                  onReopen: () => setState(() {
                    for (final line in _lines) {
                      line.mode = _LineMode.summary;
                    }
                    _lines[i].mode = _LineMode.editing;
                  }),
                  onRemove: () => _removeLine(i),
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: _canAddLine ? _addLine : null,
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

/// A product line, one of three modes (see [_LineMode]):
/// - picking: item search/list only.
/// - editing: compact tappable item-name header (tap to reopen the
///   picker and change the item) + qty/price fields, all editable.
/// - summary: one fully-collapsed, read-only row (name • qty • price) —
///   tap to reopen for editing.
class _BillLineCard extends StatelessWidget {
  final _BillLineState line;
  final VoidCallback onChanged;
  final VoidCallback onReopen;
  final VoidCallback onRemove;

  const _BillLineCard({
    required this.line,
    required this.onChanged,
    required this.onReopen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (line.mode == _LineMode.summary) {
      return _SummaryLineRow(line: line, onTap: onReopen, onRemove: onRemove);
    }

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
                child: line.mode == _LineMode.picking
                    ? BillItemPicker(
                        selectedItem: line.item,
                        onSelected: (item) {
                          line.item = item;
                          // Default the price from the item's current
                          // price — spec requirement — but only if the
                          // user hasn't already typed something, so
                          // re-picking doesn't clobber an edit.
                          if (line.priceController.text.trim().isEmpty) {
                            line.priceController.text = item.price.toStringAsFixed(0);
                          }
                          // Stays open for editing qty/price — does NOT
                          // jump straight to the summary row; that only
                          // happens once "add more" is tapped or another
                          // line is reopened.
                          line.mode = _LineMode.editing;
                          onChanged();
                        },
                      )
                    : _EditingItemHeader(
                        name: line.item?.name ?? '',
                        onTap: () {
                          line.mode = _LineMode.picking;
                          onChanged();
                        },
                      ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, color: AppColors.danger, size: 22),
              ),
            ],
          ),
          if (line.mode == _LineMode.editing) ...[
            const SizedBox(height: 12),
            // Stacked, not side-by-side — a 2-column layout left too
            // little room per field on narrower/denser screens (reported
            // on a Samsung M34: कीमत is almost always 3-4 digits, and the
            // side-by-side box was too cramped to comfortably read/type).
            FieldWithMic(
              label: Strings.itemQuantity,
              controller: line.quantityController,
              keyboardType: TextInputType.number,
              isNumeric: true,
            ),
            const SizedBox(height: 12),
            FieldWithMic(
              label: Strings.itemPrice,
              controller: line.priceController,
              keyboardType: TextInputType.number,
              prefixText: '₹ ',
              isNumeric: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// The compact tappable item-name header shown in [_LineMode.editing] —
/// tap to reopen the picker and change the item. Distinct from
/// [_SummaryLineRow]: this one still has qty/price fields visible right
/// below it (the line is actively being filled in), the summary row
/// doesn't show any fields at all.
class _EditingItemHeader extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _EditingItemHeader({required this.name, required this.onTap});

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

/// [_LineMode.summary] — one fully-collapsed, read-only row: item name,
/// then "{qty} {unit}  •  ₹{lineTotal}" underneath. Tap anywhere on the
/// row (outside the remove icon) to reopen it for editing.
class _SummaryLineRow extends StatelessWidget {
  final _BillLineState line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SummaryLineRow({required this.line, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final item = line.item;
    final quantity = int.tryParse(line.quantityController.text.trim()) ?? 0;
    final price = double.tryParse(line.priceController.text.trim()) ?? 0;
    final total = quantity * price;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$quantity ${item?.unit ?? ''}  •  ₹${total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, color: AppColors.danger, size: 22),
            ),
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
