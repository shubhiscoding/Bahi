import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/bill.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../../../core/utils/name_formatter.dart';
import '../../../core/utils/offline_guard.dart';
import '../providers/bill_providers.dart';
import '../widgets/amount_input_sheet.dart';

/// Bill detail screen (Phase 8 §G) — buyer, absolute date, line items,
/// total, "billed by" attribution, and (if due > 0) a record-payment
/// action.
class BillDetailScreen extends ConsumerWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  Future<void> _showRecordPaymentSheet(BuildContext context, WidgetRef ref, double maxAmount) async {
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
      await ref.read(addPaymentProvider((billId: billId, amount: amount)).future);
      ref.invalidate(billsForBuyerProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailProvider(billId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(Strings.bill),
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(
          child: Text(Strings.errorOccurred, style: const TextStyle(color: AppColors.danger)),
        ),
        data: (bill) {
          final editorName = bill.createdByName ?? '?';
          // The record-payment action (or the "paid" badge) is a fixed
          // footer, not the last item in the scroll view — with many
          // payments recorded, the list would otherwise push it below
          // the fold and force a scroll just to reach the one button
          // that matters most on this screen.
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.buyerName ?? '?', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        formatAbsoluteHindi(bill.billDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (final item in bill.items ?? [])
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.itemName ?? '?',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity} × ₹${item.price.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '₹${item.subtotal.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('कुल', style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  Text(
                                    '₹${bill.total.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      Strings.totalPaid,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                  ),
                                  Text(
                                    '₹${bill.paid.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      Strings.totalDue,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                  ),
                                  Text(
                                    '₹${bill.due.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: bill.due > 0 ? AppColors.danger : AppColors.inkSoft,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.avatarColorForName(editorName),
                            child: Text(
                              NameFormatter.getInitial(editorName),
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${Strings.billedBy}: ${NameFormatter.editedByFormat(editorName)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),

                      if ((bill.payments ?? []).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(Strings.paymentsMade, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < bill.payments!.length; i++) ...[
                                _PaymentRow(payment: bill.payments![i]),
                                if (i < bill.payments!.length - 1)
                                  Divider(height: 1, color: AppColors.border),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Fixed footer, always reachable without scrolling.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: bill.due > 0
                      ? ElevatedButton.icon(
                          onPressed: () => _showRecordPaymentSheet(context, ref, bill.due),
                          icon: const Icon(Icons.payments, size: 22),
                          label: Text('${Strings.recordPayment} (₹${bill.due.toStringAsFixed(0)} बाकी)'),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            Strings.paid,
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One row in the "payments made" list — amount, absolute date, and who
/// recorded it (same avatar+short-name attribution pattern used
/// elsewhere for "edited by"/"billed by").
class _PaymentRow extends StatelessWidget {
  final BillPaymentRecord payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.avatarColorForName(payment.recordedByName),
            child: Text(
              NameFormatter.getInitial(payment.recordedByName),
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NameFormatter.editedByFormat(payment.recordedByName),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  formatAbsoluteHindi(payment.paidAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '₹${payment.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
          ),
        ],
      ),
    );
  }
}
