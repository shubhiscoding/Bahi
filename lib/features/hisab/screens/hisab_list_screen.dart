import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/bill.dart';
import '../../../core/models/hisab.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../../../core/utils/currency_format.dart';
import '../../buyers/screens/bill_detail_screen.dart';
import '../../buyers/screens/deposit_detail_screen.dart';
import '../models/hisab_date_filter.dart';
import '../providers/hisab_providers.dart';
import '../repositories/hisab_repository.dart';
import '../widgets/hisab_date_filter_row.dart';
import '../widgets/hisab_totals_card.dart';

enum HisabListMode { allBills, unpaidBills, payments }

class HisabListScreen extends ConsumerStatefulWidget {
  final HisabListMode mode;
  final HisabDateFilter initialFilter;

  const HisabListScreen({super.key, required this.mode, required this.initialFilter});

  @override
  ConsumerState<HisabListScreen> createState() => _HisabListScreenState();
}

class _HisabListScreenState extends ConsumerState<HisabListScreen> {
  late HisabDateFilter _filter = widget.initialFilter;
  HisabSort _sort = HisabSort.newest;

  String get _title => switch (widget.mode) {
        HisabListMode.allBills => 'सभी बिल',
        HisabListMode.unpaidBills => 'बाकी बिल',
        HisabListMode.payments => 'पैसे मिले',
      };

  HisabBillsQuery get _billQuery => HisabBillsQuery(
        filter: _filter,
        sort: _sort,
        unpaidOnly: widget.mode == HisabListMode.unpaidBills,
      );

  Future<void> _refreshBills() async {
    await Future.wait<Object?>([
      ref.refresh(hisabSummaryProvider(_filter).future),
      ref.refresh(hisabBillsProvider(_billQuery).future),
    ]);
  }

  Future<void> _refreshPayments() async {
    await Future.wait<Object?>([
      ref.refresh(hisabSummaryProvider(_filter).future),
      ref.refresh(hisabPaymentsProvider((filter: _filter, sort: _sort)).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(hisabSummaryProvider(_filter));
    final billsAsync = widget.mode == HisabListMode.payments ? null : ref.watch(hisabBillsProvider(_billQuery));
    final paymentsQuery = (filter: _filter, sort: _sort);
    final paymentsAsync = widget.mode == HisabListMode.payments ? ref.watch(hisabPaymentsProvider(paymentsQuery)) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(_title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: HisabDateFilterRow(value: _filter, onChanged: (filter) => setState(() => _filter = filter)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: summaryAsync.when(
              loading: () => const SizedBox(height: 84, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (error, stack) => _InlineError(onRetry: () => ref.invalidate(hisabSummaryProvider(_filter))),
              data: (summary) => HisabTotalsCard(
                totalBilled: summary.totalBilled,
                totalDue: summary.totalDue,
                totalReceived: summary.totalReceived,
                mode: switch (widget.mode) {
                  HisabListMode.allBills => HisabTotalsMode.all,
                  HisabListMode.unpaidBills => HisabTotalsMode.due,
                  HisabListMode.payments => HisabTotalsMode.received,
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SortMenu(value: _sort, onChanged: (sort) => setState(() => _sort = sort)),
            ),
          ),
          Expanded(
            child: widget.mode == HisabListMode.payments
                ? paymentsAsync!.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (error, stack) => _InlineError(onRetry: () => ref.invalidate(hisabPaymentsProvider(paymentsQuery))),
                    data: (payments) => payments.isEmpty
                        ? _EmptyState(message: Strings.noDepositsYet)
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _refreshPayments,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: payments.length,
                              itemBuilder: (context, index) => _PaymentCard(payment: payments[index]),
                            ),
                          ),
                  )
                : billsAsync!.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (error, stack) => _InlineError(onRetry: () => ref.invalidate(hisabBillsProvider(_billQuery))),
                    data: (bills) => bills.isEmpty
                        ? _EmptyState(message: Strings.noBillsYet)
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _refreshBills,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: bills.length,
                              itemBuilder: (context, index) => _BillCard(
                                bill: bills[index],
                                unpaidMode: widget.mode == HisabListMode.unpaidBills,
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final HisabSort value;
  final ValueChanged<HisabSort> onChanged;

  const _SortMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => PopupMenuButton<HisabSort>(
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (context) => const [
          PopupMenuItem(value: HisabSort.newest, child: Text('सबसे नया पहले')),
          PopupMenuItem(value: HisabSort.oldest, child: Text('सबसे पुराना पहले')),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('क्रम: ${value == HisabSort.newest ? 'सबसे नया पहले' : 'सबसे पुराना पहले'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      );
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  final bool unpaidMode;

  const _BillCard({required this.bill, required this.unpaidMode});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.due <= 0;
    final amount = unpaidMode ? bill.due : bill.total;
    final days = DateTime.now().difference(DateTime(bill.billDate.toLocal().year, bill.billDate.toLocal().month, bill.billDate.toLocal().day)).inDays;
    return _ReportCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.buyerName ?? 'खरीदार', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('बिल · ${formatDateDDMMYY(bill.billDate)}', style: TextStyle(color: AppColors.inkSoft)),
                if (!unpaidMode && bill.paid > 0 && !isPaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${formatIndianRupees(bill.paid)} भुगतान हुआ', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                if (unpaidMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text('${days <= 0 ? 'आज' : '$days दिन'} से बाकी', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatIndianRupees(amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: unpaidMode && bill.due > 0 ? AppColors.danger : AppColors.inkPrimary)),
              if (!unpaidMode) ...[
                const SizedBox(height: 7),
                _StatusPill(text: isPaid ? Strings.paid : Strings.unpaid, color: isPaid ? AppColors.success : AppColors.danger),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final HisabPaymentRecord payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) => _ReportCard(
        onTap: () {
          if (payment.depositId != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => DepositDetailScreen(depositId: payment.depositId!)));
          } else if (payment.billId != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => BillDetailScreen(billId: payment.billId!)));
          }
        },
        child: Row(
          children: [
            const CircleAvatar(radius: 22, backgroundColor: AppColors.primarySoft, child: Icon(Icons.payments_outlined, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment.buyerName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${formatDateDDMMYY(payment.paidAt)} · ${payment.recordedByName}', style: TextStyle(color: AppColors.inkSoft), overflow: TextOverflow.ellipsis),
                  if (payment.legacy)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text('पुराना बिल भुगतान', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatIndianRupees(payment.amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _ReportCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ReportCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _InlineError extends StatelessWidget {
  final VoidCallback onRetry;

  const _InlineError({required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 84,
        child: Center(
          child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('फिर कोशिश करें')),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Center(child: Text(message, style: const TextStyle(color: AppColors.inkSoft)));
}
