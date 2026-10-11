import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_format.dart';

enum HisabTotalsMode { all, due, received }

class HisabTotalsCard extends StatelessWidget {
  final double totalBilled;
  final double totalDue;
  final double totalReceived;
  final HisabTotalsMode mode;
  final ValueChanged<HisabTotalsMode>? onTap;

  const HisabTotalsCard({
    super.key,
    required this.totalBilled,
    required this.totalDue,
    required this.totalReceived,
    this.mode = HisabTotalsMode.all,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = switch (mode) {
      HisabTotalsMode.all => <HisabTotalsMode>[HisabTotalsMode.all, HisabTotalsMode.due, HisabTotalsMode.received],
      HisabTotalsMode.due => <HisabTotalsMode>[HisabTotalsMode.due],
      HisabTotalsMode.received => <HisabTotalsMode>[HisabTotalsMode.received],
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final row in rows) ...[
            _TotalsRow(
              mode: row,
              amount: formatIndianRupees(switch (row) {
                HisabTotalsMode.all => totalBilled,
                HisabTotalsMode.due => totalDue,
                HisabTotalsMode.received => totalReceived,
              }),
              onTap: onTap == null ? null : () => onTap!(row),
            ),
            if (row != rows.last) Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final HisabTotalsMode mode;
  final String amount;
  final VoidCallback? onTap;

  const _TotalsRow({required this.mode, required this.amount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final due = mode == HisabTotalsMode.due;
    final received = mode == HisabTotalsMode.received;
    final label = switch (mode) {
      HisabTotalsMode.all => 'कुल बिल',
      HisabTotalsMode.due => 'कुल बाकी',
      HisabTotalsMode.received => 'पैसे मिले',
    };
    final color = due ? AppColors.danger : received ? AppColors.success : AppColors.inkPrimary;
    final icon = switch (mode) {
      HisabTotalsMode.all => Icons.receipt_long,
      HisabTotalsMode.due => Icons.error,
      HisabTotalsMode.received => Icons.check_circle,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: due
                      ? AppColors.dangerSoft
                      : received
                          ? AppColors.success.withValues(alpha: 0.13)
                          : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 25, color: due ? AppColors.danger : received ? AppColors.success : AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft)),
                    if (due && onTap != null)
                      const Text('पूरी सूची देखें', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  amount,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
