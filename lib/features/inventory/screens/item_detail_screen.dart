import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/price_history_point.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/absolute_time.dart';
import '../../../core/utils/name_formatter.dart';
import '../../team/providers/team_providers.dart';
import '../providers/inventory_providers.dart';
import 'add_edit_item_screen.dart';

enum _PriceRange { allTime, last7Days, lastMonth }

/// Item Detail ("about this item") screen — read-only view reached by
/// tapping an item card. Shows name/price/quantity/unit/edited-by/absolute
/// updated-at, a price-tracker chart, and a top-right edit button that
/// pushes the unchanged AddEditItemScreen (Phase 7 §B).
class ItemDetailScreen extends ConsumerStatefulWidget {
  final InventoryItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  _PriceRange _range = _PriceRange.allTime;

  @override
  Widget build(BuildContext context) {
    final teamMembers = ref.watch(teamMembersProvider).value ?? [];
    final editor =
        teamMembers.where((m) => m.userId == widget.item.updatedBy).firstOrNull;
    final editorName = editor?.fullName ?? '?';
    final historyAsync = ref.watch(priceHistoryProvider(widget.item.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.inkPrimary,
        title: Text(widget.item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: Strings.editItem,
            icon: const Icon(Icons.edit, size: 26),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddEditItemScreen(item: widget.item)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailCard(item: widget.item, editorName: editorName),
            const SizedBox(height: 24),
            Text('कीमत का इतिहास', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _RangeSelector(
              value: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (err, stack) => _chartErrorState(),
              data: (history) => _PriceChart(
                points: _pointsForRange(history, _range),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PriceHistoryPoint> _pointsForRange(List<PriceHistoryPoint> all, _PriceRange range) {
    if (range == _PriceRange.allTime) return all;
    final cutoff = range == _PriceRange.last7Days
        ? DateTime.now().subtract(const Duration(days: 7))
        : DateTime.now().subtract(const Duration(days: 30));
    return all.where((p) => p.recordedAt.isAfter(cutoff)).toList();
  }

  Widget _chartErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              Strings.errorOccurred,
              style: const TextStyle(fontSize: 16, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final InventoryItem item;
  final String editorName;

  const _DetailCard({required this.item, required this.editorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '₹${item.price.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.quantity} ${item.unit}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
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
              Expanded(
                child: Text(
                  '${Strings.editedBy} ${NameFormatter.editedByFormat(editorName)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatAbsoluteHindi(item.updatedAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final _PriceRange value;
  final ValueChanged<_PriceRange> onChanged;

  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = {
      _PriceRange.allTime: 'सभी समय',
      _PriceRange.last7Days: '7 दिन',
      _PriceRange.lastMonth: '1 महीना',
    };

    return Row(
      children: options.entries.map((entry) {
        final isSelected = value == entry.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onChanged(entry.key),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.inkPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PriceChart extends StatelessWidget {
  final List<PriceHistoryPoint> points;

  const _PriceChart({required this.points});

  @override
  Widget build(BuildContext context) {
    // Plain-language empty state (design.md rule 11) rather than a
    // blank/broken chart when there's under 2 points in this window.
    if (points.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 40, color: AppColors.inkSoft),
              const SizedBox(height: 12),
              Text(
                'अभी कीमत का इतिहास नहीं है',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].price));
    }

    final minY = points.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15 + 1;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (points.length / 4).clamp(1, points.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  final d = points[index].recordedAt;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppColors.primarySoft),
            ),
          ],
          // Default tooltip is dark-on-dark (unreadable) — use a light
          // surface with dark ink text to match the app's design tokens.
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppColors.surface,
              tooltipBorder: const BorderSide(color: AppColors.border),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '₹${spot.y.toStringAsFixed(0)}',
                    const TextStyle(
                      color: AppColors.inkPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
