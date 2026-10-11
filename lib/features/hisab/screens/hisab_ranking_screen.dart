import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_format.dart';
import '../models/hisab_date_filter.dart';
import '../providers/hisab_providers.dart';
import '../widgets/hisab_date_filter_row.dart';

class HisabRankingScreen extends ConsumerStatefulWidget {
  final String kind;
  final String title;
  final HisabDateFilter initialFilter;

  const HisabRankingScreen({super.key, required this.kind, required this.title, required this.initialFilter});

  @override
  ConsumerState<HisabRankingScreen> createState() => _HisabRankingScreenState();
}

class _HisabRankingScreenState extends ConsumerState<HisabRankingScreen> {
  late HisabDateFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final query = (filter: _filter, kind: widget.kind);
    final rankingsAsync = ref.watch(hisabRankingsProvider(query));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: HisabDateFilterRow(value: _filter, onChanged: (filter) => setState(() => _filter = filter)),
          ),
          Expanded(
            child: rankingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, stack) => Center(
                child: TextButton.icon(onPressed: () => ref.invalidate(hisabRankingsProvider(query)), icon: const Icon(Icons.refresh), label: const Text('फिर कोशिश करें')),
              ),
              data: (entries) => entries.isEmpty
                  ? const Center(child: Text('इस अवधि में कोई बिक्री नहीं', style: TextStyle(color: AppColors.inkSoft)))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        await ref.refresh(hisabRankingsProvider(query).future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 34, child: Text('${index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entries[index].name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Text(formatIndianRupees(entries[index].amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
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
