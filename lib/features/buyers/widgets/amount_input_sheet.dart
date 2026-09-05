import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Shared "enter an amount" bottom sheet — used by both the per-bill
/// record-payment action (bill_detail_screen.dart) and the buyer-level
/// record-payment action (buyer_detail_screen.dart, Phase 9). Extracted
/// once it was needed a second time, matching this session's own
/// precedent (FieldWithMic).
///
/// isScrollControlled + viewInsets.bottom padding: without both, the
/// sheet doesn't resize when the keyboard opens — it just gets covered,
/// hiding the amount field being typed into (a real bug fixed earlier).
Future<double?> showAmountInputSheet(
  BuildContext context, {
  required String title,
  required String hintText,
  required String confirmLabel,
  double? initialValue,
}) {
  final controller = TextEditingController(
    text: initialValue != null ? initialValue.toStringAsFixed(0) : '',
  );
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                Navigator.of(sheetContext).pop(value);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
