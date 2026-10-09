import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';

class PaymentEntryInput {
  final double amount;
  final DateTime paidAt;

  const PaymentEntryInput({required this.amount, required this.paidAt});
}

/// Shared "enter payment details" bottom sheet — used by both the per-bill
/// record-payment action (bill_detail_screen.dart) and the buyer-level
/// record-payment action (buyer_detail_screen.dart, Phase 9). Extracted
/// once it was needed a second time, matching this session's own
/// precedent (FieldWithMic).
///
/// isScrollControlled + viewInsets.bottom padding: without both, the
/// sheet doesn't resize when the keyboard opens — it just gets covered,
/// hiding the amount field being typed into (a real bug fixed earlier).
Future<PaymentEntryInput?> showAmountInputSheet(
  BuildContext context, {
  required String title,
  required String hintText,
  required String confirmLabel,
  double? initialValue,
}) {
  final controller = TextEditingController(
    text: initialValue != null ? initialValue.toStringAsFixed(0) : '',
  );
  var paymentDate = DateTime.now();
  return showModalBottomSheet<PaymentEntryInput>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(prefixText: '₹ ', hintText: hintText),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setSheetState) => InkWell(
                  onTap: () async {
                    final today = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      locale: const Locale('en', 'GB'),
                      fieldHintText: 'DD/MM/YY',
                      initialDate: paymentDate,
                      firstDate: DateTime(2000),
                      lastDate: today,
                    );
                    if (picked != null) setSheetState(() => paymentDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      border: Border.all(color: AppColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: AppColors.inkPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('भुगतान की तारीख़'),
                              Text(
                                formatDateDDMMYY(paymentDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar, color: AppColors.inkPrimary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final value = double.tryParse(controller.text.trim());
                  if (value == null) {
                    Navigator.of(sheetContext).pop();
                    return;
                  }
                  final now = DateTime.now();
                  Navigator.of(sheetContext).pop(
                    PaymentEntryInput(
                      amount: value,
                      paidAt: DateTime(
                        paymentDate.year,
                        paymentDate.month,
                        paymentDate.day,
                        now.hour,
                        now.minute,
                        now.second,
                        now.millisecond,
                      ),
                    ),
                  );
                },
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
