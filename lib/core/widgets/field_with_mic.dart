import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'voice_confirm_sheet.dart';

/// A text field with a mic button (design.md rule 1: voice is the primary
/// input, typing is the fallback — mic is the largest, most dominant
/// control on this row). Extracted from add_edit_item_screen.dart
/// (Phase 8) since it's now needed in 3+ places: the add-stock sheet, bill
/// line-item qty/price fields, and the original add/edit item form.
class FieldWithMic extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefixText;
  final bool isNumeric;

  const FieldWithMic({
    super.key,
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.prefixText,
    this.isNumeric = false,
  });

  Future<void> _handleMicTap(BuildContext context) async {
    final heardText = await showVoiceInputSheet(context, fieldLabel: label);
    if (heardText == null) return;

    if (isNumeric) {
      // Best-effort: pull digits out of the recognized speech. Spoken
      // Hindi number words (e.g. "पांच सौ") aren't parsed — the digit
      // extraction covers the common case where the recognizer already
      // returns numerals, and the field remains editable either way.
      final digits = RegExp(r'\d+').firstMatch(heardText)?.group(0);
      controller.text = digits ?? heardText;
    } else {
      controller.text = heardText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mic button — largest, most dominant control (rule 1)
            InkWell(
              onTap: () => _handleMicTap(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  prefixText: prefixText,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
