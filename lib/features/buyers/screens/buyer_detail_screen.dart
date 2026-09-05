import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/bill.dart';
import '../../../core/models/buyer.dart';
import '../../../core/models/deposit.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../../../core/utils/offline_guard.dart';
import '../providers/bill_providers.dart';
import '../providers/buyer_providers.dart';
import '../providers/deposit_providers.dart';
import '../widgets/amount_input_sheet.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'deposit_detail_screen.dart';

enum _DateRange { allTime, last7Days, lastMonth, custom }

enum _PaidFilter { all, paid, unpaid }

enum _ListMode { bills, deposits }

/// Buyer "about" page (Phase 8 §G) — mirrors item_detail_screen.dart's
/// layout: name, total billed/paid/due, then (in place of a chart) a
/// filterable scrollable list of this buyer's bills.
class BuyerDetailScreen extends ConsumerStatefulWidget {
  final Buyer buyer;

  const BuyerDetailScreen({super.key, required this.buyer});

  @override
  ConsumerState<BuyerDetailScreen> createState() => _BuyerDetailScreenState();
}

class _BuyerDetailScreenState extends ConsumerState<BuyerDetailScreen> {
  _DateRange _dateRange = _DateRange.allTime;
  _PaidFilter _paidFilter = _PaidFilter.all;
  _ListMode _listMode = _ListMode.bills;
  DateTimeRange? _customRange;

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _dateRange = _DateRange.custom;
      });
    }
  }

  /// Buyer-level "record payment" (Phase 9) — one amount, allocated
  /// server-side across this buyer's outstanding bills oldest-first.
  Future<void> _showRecordPaymentSheet(double maxAmount) async {
    final amount = await showAmountInputSheet(
      context,
      title: Strings.recordPayment,
      hintText: Strings.paymentAmount,
      confirmLabel: Strings.recordPayment,
      initialValue: maxAmount,
    );

    if (amount == null || amount <= 0) return;
    if (!await ensureOnline(context)) return;
    try {
      await ref.read(
        recordBuyerPaymentProvider((buyerId: widget.buyer.id, amount: amount)).future,
      );
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
    final detailAsync = ref.watch(buyerDetailProvider(widget.buyer.id));
    final billsAsync = ref.watch(billsForBuyerProvider(BillsForBuyerQuery(buyerId: widget.buyer.id)));
    final depositsAsync =
        ref.watch(depositsForBuyerProvider(DepositsForBuyerQuery(buyerId: widget.buyer.id)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(widget.buyer.name, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  detailAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, stack) => Text(
                      Strings.errorOccurred,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    data: (detail) => _TotalsCard(detail: detail),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _listMode == _ListMode.bills ? 'बिल' : Strings.deposits,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _ListModeToggle(
                        value: _listMode,
                        onChanged: (m) => setState(() => _listMode = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Paid/unpaid isn't a meaningful concept for a deposit
                  // — only shown in bills mode.
                  if (_listMode == _ListMode.bills) ...[
                    _PaidFilterRow(
                      value: _paidFilter,
                      onChanged: (f) => setState(() => _paidFilter = f),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _DateRangeRow(
                    value: _dateRange,
                    customRange: _customRange,
                    onChanged: (r) => setState(() => _dateRange = r),
                    onPickCustom: _pickCustomRange,
                  ),
                  const SizedBox(height: 16),
                  if (_listMode == _ListMode.bills)
                    billsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(Strings.errorOccurred, style: const TextStyle(color: AppColors.danger)),
                      ),
                      data: (bills) {
                        final filtered = _filterBills(bills);
                        if (filtered.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                Strings.noBillsYet,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: filtered.map((bill) => _BillCard(bill: bill)).toList(),
                        );
                      },
                    )
                  else
                    depositsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(Strings.errorOccurred, style: const TextStyle(color: AppColors.danger)),
                      ),
                      data: (deposits) {
                        final filtered = _filterDeposits(deposits);
                        if (filtered.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                Strings.noDepositsYet,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: filtered.map((deposit) => _DepositCard(deposit: deposit)).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Fixed footer, always reachable without scrolling — same
          // proven pattern as bill_detail_screen.dart (a plain Column +
          // Expanded inside body, NOT Scaffold.bottomNavigationBar — that
          // slot doesn't self-constrain a plain Container's height the
          // way Expanded does, which is what caused a regression: a
          // short bill list rendered as a full-screen button).
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: detailAsync.when(
                loading: () => const SizedBox(height: 56),
                error: (err, stack) => const SizedBox.shrink(),
                data: (detail) => detail.totalDue > 0
                    ? ElevatedButton.icon(
                        onPressed: () => _showRecordPaymentSheet(detail.totalDue),
                        icon: const Icon(Icons.payments, size: 22),
                        label: Text(
                          '${Strings.recordPayment} (₹${detail.totalDue.toStringAsFixed(0)} बाकी)',
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Strings.allPaidUp,
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      // A true floating button, like the "बिल बनाएँ" FAB on the Bill tab
      // — offset upward so it clears the fixed footer above instead of
      // overlapping it (the footer is inside body, not
      // bottomNavigationBar, so Scaffold doesn't know about it and would
      // otherwise place this FAB right on top of it).
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddBillScreen(initialBuyer: widget.buyer)),
            );
          },
          icon: const Icon(Icons.receipt_long, size: 24),
          label: Text(Strings.createBill, style: Theme.of(context).textTheme.labelLarge),
        ),
      ),
    );
  }

  List<Bill> _filterBills(List<Bill> all) {
    var result = all;
    if (_paidFilter != _PaidFilter.all) {
      result = result.where((b) => _paidFilter == _PaidFilter.paid ? b.isPaid : !b.isPaid).toList();
    }
    if (_dateRange == _DateRange.custom && _customRange != null) {
      // End-of-day on the end date so a bill made ON that day is included.
      final start = _customRange!.start;
      final end = _customRange!.end.add(const Duration(days: 1));
      result = result.where((b) => !b.billDate.isBefore(start) && b.billDate.isBefore(end)).toList();
    } else if (_dateRange == _DateRange.last7Days || _dateRange == _DateRange.lastMonth) {
      final cutoff = _dateRange == _DateRange.last7Days
          ? DateTime.now().subtract(const Duration(days: 7))
          : DateTime.now().subtract(const Duration(days: 30));
      result = result.where((b) => b.billDate.isAfter(cutoff)).toList();
    }
    return result;
  }

  List<Deposit> _filterDeposits(List<Deposit> all) {
    var result = all;
    if (_dateRange == _DateRange.custom && _customRange != null) {
      final start = _customRange!.start;
      final end = _customRange!.end.add(const Duration(days: 1));
      result = result.where((d) => !d.paidAt.isBefore(start) && d.paidAt.isBefore(end)).toList();
    } else if (_dateRange == _DateRange.last7Days || _dateRange == _DateRange.lastMonth) {
      final cutoff = _dateRange == _DateRange.last7Days
          ? DateTime.now().subtract(const Duration(days: 7))
          : DateTime.now().subtract(const Duration(days: 30));
      result = result.where((d) => d.paidAt.isAfter(cutoff)).toList();
    }
    return result;
  }
}

class _ListModeToggle extends StatelessWidget {
  final _ListMode value;
  final ValueChanged<_ListMode> onChanged;

  const _ListModeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget button(_ListMode mode, IconData icon, String label) {
      final isSelected = value == mode;
      return InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppColors.primary : AppColors.inkSoft,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        button(_ListMode.bills, Icons.receipt_long, 'बिल'),
        const SizedBox(width: 8),
        button(_ListMode.deposits, Icons.savings, Strings.deposits),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final BuyerDetail detail;

  const _TotalsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _StatColumn(label: Strings.totalBilled, value: detail.totalBilled, color: AppColors.inkPrimary)),
          Expanded(child: _StatColumn(label: Strings.totalPaid, value: detail.totalPaid, color: AppColors.success)),
          Expanded(child: _StatColumn(label: Strings.totalDue, value: detail.totalDue, color: AppColors.danger)),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _PaidFilterRow extends StatelessWidget {
  final _PaidFilter value;
  final ValueChanged<_PaidFilter> onChanged;

  const _PaidFilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = {
      _PaidFilter.all: 'सभी',
      _PaidFilter.paid: 'भुगतान हुआ',
      _PaidFilter.unpaid: 'बाकी है',
    };
    return Wrap(
      spacing: 8,
      children: options.entries.map((entry) {
        final isSelected = value == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (_) => onChanged(entry.key),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.inkPrimary),
        );
      }).toList(),
    );
  }
}

class _DateRangeRow extends StatelessWidget {
  final _DateRange value;
  final DateTimeRange? customRange;
  final ValueChanged<_DateRange> onChanged;
  final VoidCallback onPickCustom;

  const _DateRangeRow({
    required this.value,
    required this.customRange,
    required this.onChanged,
    required this.onPickCustom,
  });

  @override
  Widget build(BuildContext context) {
    const options = {
      _DateRange.allTime: 'सभी समय',
      _DateRange.last7Days: '7 दिन',
      _DateRange.lastMonth: '1 महीना',
    };

    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primarySoft,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.inkSoft,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    final customLabel = value == _DateRange.custom && customRange != null
        ? '${customRange!.start.day}/${customRange!.start.month} - ${customRange!.end.day}/${customRange!.end.month}'
        : 'तारीख़ चुनें';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...options.entries.map(
          (entry) => chip(entry.value, value == entry.key, () => onChanged(entry.key)),
        ),
        // Tapping this always opens the range picker — re-tapping when
        // already selected lets the user change the range, not just
        // confirm it's chosen.
        chip(customLabel, value == _DateRange.custom, onPickCustom),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('₹${bill.total.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                        // Partial payment (paid something, but not fully) —
                        // called out next to the amount so it's not
                        // mistaken for a plain unpaid bill.
                        if (bill.paid > 0 && !bill.isPaid) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${bill.paid.toStringAsFixed(0)} ${Strings.partialPaymentSuffix}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatAbsoluteHindi(bill.billDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bill.isPaid ? AppColors.success.withValues(alpha: 0.15) : AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bill.isPaid ? Strings.paid : Strings.unpaid,
                  style: TextStyle(
                    color: bill.isPaid ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final Deposit deposit;

  const _DepositCard({required this.deposit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DepositDetailScreen(depositId: deposit.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.savings, color: AppColors.success, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${deposit.amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatAbsoluteHindi(deposit.paidAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
