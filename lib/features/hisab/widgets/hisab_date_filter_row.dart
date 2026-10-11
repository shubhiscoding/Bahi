import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../models/hisab_date_filter.dart';

class HisabDateFilterRow extends StatelessWidget {
  final HisabDateFilter value;
  final ValueChanged<HisabDateFilter> onChanged;

  const HisabDateFilterRow({super.key, required this.value, required this.onChanged});

  Future<void> _pickRange(BuildContext context) async {
    final initial = value.dateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('en', 'GB'),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: initial.start.isBefore(DateTime(2000)) ? DateTime(2000) : initial.start,
        end: initial.end.isAfter(DateTime.now()) ? DateTime.now() : initial.end,
      ),
      helpText: 'तारीख़ की सीमा चुनें',
    );
    if (picked != null) onChanged(HisabDateFilter.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final customText = value.preset == HisabDatePreset.custom
        ? '${formatDateDDMMYY(value.customStart!)} - ${formatDateDDMMYY(value.customEnd!)}'
        : 'तारीख़ चुनें';

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onTap(),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.inkPrimary,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        );

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('1 महीना', value.preset == HisabDatePreset.oneMonth, () => onChanged(HisabDateFilter.oneMonth())),
          chip('6 महीने', value.preset == HisabDatePreset.sixMonths, () => onChanged(HisabDateFilter.sixMonths())),
          chip('1 साल', value.preset == HisabDatePreset.oneYear, () => onChanged(HisabDateFilter.oneYear())),
          chip('सभी समय', value.preset == HisabDatePreset.allTime, () => onChanged(HisabDateFilter.allTime())),
          chip(
            customText,
            value.preset == HisabDatePreset.custom,
            () => _pickRange(context),
          ),
        ],
      ),
    );
  }
}
