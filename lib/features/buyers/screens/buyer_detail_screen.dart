import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/bill.dart';
import '../../../core/models/buyer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../providers/bill_providers.dart';
import '../providers/buyer_providers.dart';
import 'bill_detail_screen.dart';

enum _DateRange { allTime, last7Days, lastMonth, custom }

enum _PaidFilter { all, paid, unpaid }

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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(buyerDetailProvider(widget.buyer.id));
    final billsAsync = ref.watch(billsForBuyerProvider(BillsForBuyerQuery(buyerId: widget.buyer.id)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(widget.buyer.name, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Text(Strings.errorOccurred, style: const TextStyle(color: AppColors.danger)),
              data: (detail) => _TotalsCard(detail: detail),
            ),
            const SizedBox(height: 24),
            Text('बिल', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _PaidFilterRow(
              value: _paidFilter,
              onChanged: (f) => setState(() => _paidFilter = f),
            ),
            const SizedBox(height: 8),
            _DateRangeRow(
              value: _dateRange,
              customRange: _customRange,
              onChanged: (r) => setState(() => _dateRange = r),
              onPickCustom: _pickCustomRange,
            ),
            const SizedBox(height: 16),
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
            ),
          ],
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
