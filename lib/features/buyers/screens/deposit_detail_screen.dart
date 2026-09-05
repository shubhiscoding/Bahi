import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/deposit.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../../../core/utils/name_formatter.dart';
import '../providers/deposit_providers.dart';
import 'bill_detail_screen.dart';

/// Deposit detail screen (Phase 10) — total deposited, absolute
/// date/time, who recorded it, and the list of bills it settled with how
/// much went to each. Read-only — no further action here, it's a receipt.
class DepositDetailScreen extends ConsumerWidget {
  final String depositId;

  const DepositDetailScreen({super.key, required this.depositId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositAsync = ref.watch(depositDetailProvider(depositId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(Strings.deposits),
      ),
      body: depositAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(
          child: Text(Strings.errorOccurred, style: const TextStyle(color: AppColors.danger)),
        ),
        data: (deposit) {
          final recorderName = deposit.recordedByName;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${deposit.amount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatAbsoluteHindi(deposit.paidAt),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.avatarColorForName(recorderName),
                      child: Text(
                        NameFormatter.getInitial(recorderName),
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Strings.recordPayment}: ${NameFormatter.editedByFormat(recorderName)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(Strings.settledBills, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < (deposit.bills ?? []).length; i++) ...[
                        _SettledBillRow(allocation: deposit.bills![i]),
                        if (i < deposit.bills!.length - 1) Divider(height: 1, color: AppColors.border),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettledBillRow extends StatelessWidget {
  final DepositBillAllocation allocation;

  const _SettledBillRow({required this.allocation});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BillDetailScreen(billId: allocation.billId)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatAbsoluteHindi(allocation.billDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'बिल की कुल राशि: ₹${allocation.billTotal.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            Text(
              '₹${allocation.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
