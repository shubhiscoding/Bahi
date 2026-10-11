import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/strings.dart';
import '../../../core/models/hisab.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/services/socket_service.dart';
import '../../business/providers/business_providers.dart';
import '../models/hisab_date_filter.dart';
import '../providers/hisab_providers.dart';
import '../widgets/hisab_date_filter_row.dart';
import '../widgets/hisab_totals_card.dart';
import 'hisab_list_screen.dart';
import 'hisab_ranking_screen.dart';

class HisabDashboardScreen extends ConsumerStatefulWidget {
  const HisabDashboardScreen({super.key});

  @override
  ConsumerState<HisabDashboardScreen> createState() => _HisabDashboardScreenState();
}

class _HisabDashboardScreenState extends ConsumerState<HisabDashboardScreen> {
  late HisabDateFilter _filter = HisabDateFilter.oneMonth();
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForBillChanges());
  }

  void _listenForBillChanges() {
    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null || !mounted) return;
    final socket = SocketService.connect();
    _socket = socket;
    SocketService.joinBusiness(business.id);
    socket.on('bill:created', _onBillChanged);
    socket.on('bill:updated', _onBillChanged);
  }

  void _onBillChanged(dynamic _) {
    ref.invalidate(hisabSummaryProvider);
    ref.invalidate(hisabBillsProvider);
    ref.invalidate(hisabPaymentsProvider);
    ref.invalidate(hisabRankingsProvider);
  }

  @override
  void dispose() {
    _socket?.off('bill:created', _onBillChanged);
    _socket?.off('bill:updated', _onBillChanged);
    super.dispose();
  }

  void _openList(HisabListMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HisabListScreen(mode: mode, initialFilter: _filter)),
    );
  }

  void _openRanking(String kind, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HisabRankingScreen(kind: kind, title: title, initialFilter: _filter),
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    await ref.refresh(hisabSummaryProvider(_filter).future);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(hisabSummaryProvider(_filter));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshDashboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            HisabDateFilterRow(value: _filter, onChanged: (filter) => setState(() => _filter = filter)),
            const SizedBox(height: 14),
            summaryAsync.when(
              loading: () => const _DashboardLoading(),
              error: (error, stack) => _DashboardError(onRetry: () => ref.invalidate(hisabSummaryProvider(_filter))),
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HisabTotalsCard(
                    totalBilled: summary.totalBilled,
                    totalDue: summary.totalDue,
                    totalReceived: summary.totalReceived,
                    onTap: (row) => _openList(switch (row) {
                      HisabTotalsMode.all => HisabListMode.allBills,
                      HisabTotalsMode.due => HisabListMode.unpaidBills,
                      HisabTotalsMode.received => HisabListMode.payments,
                    }),
                  ),
                  const SizedBox(height: 24),
                  _RankPreview(
                    title: 'सबसे ज़्यादा ख़रीदने वाले ग्राहक',
                    rows: summary.topBuyers,
                    onSeeAll: () => _openRanking('buyers', 'सब ग्राहक'),
                  ),
                  const SizedBox(height: 26),
                  _RankPreview(
                    title: 'सबसे ज़्यादा बिकने वाला सामान',
                    rows: summary.topProducts,
                    onSeeAll: () => _openRanking('products', 'सब सामान'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(height: 190, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18))),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
}

class _DashboardError extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 8),
              const Text(Strings.errorOccurred),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('फिर कोशिश करें')),
            ],
          ),
        ),
      );
}

class _RankPreview extends StatelessWidget {
  final String title;
  final List<HisabRankEntry> rows;
  final VoidCallback onSeeAll;

  const _RankPreview({required this.title, required this.rows, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('इस अवधि में कोई बिक्री नहीं', style: TextStyle(color: AppColors.inkSoft)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('${index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(rows[index].name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(formatIndianRupees(rows[index].amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  if (index != rows.length - 1) Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            child: const Text('सब देखें', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

