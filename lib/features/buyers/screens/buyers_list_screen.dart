import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/buyer.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/search_match.dart';
import '../../../core/widgets/mic_search_field.dart';
import '../providers/buyer_providers.dart';
import 'add_bill_screen.dart';
import 'buyer_detail_screen.dart';

/// Bill tab (Phase 8 §G) — "list of buyers we have billed" (per spec),
/// search bar, single FAB to create a new bill. Same list+search+FAB+
/// empty-state shape as InventoryListScreen.
class BuyersListScreen extends ConsumerStatefulWidget {
  const BuyersListScreen({super.key});

  @override
  ConsumerState<BuyersListScreen> createState() => _BuyersListScreenState();
}

class _BuyersListScreenState extends ConsumerState<BuyersListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyersAsync = ref.watch(buyersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: MicSearchField(
              controller: _searchController,
              hintText: 'खरीदार खोजें',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: buyersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => _errorState(),
              data: (buyers) {
                final filtered = _searchQuery.isEmpty
                    ? buyers
                    : buyers.where((b) => matchesSearch(b.name, _searchQuery)).toList();

                if (buyers.isEmpty) return _emptyState();
                if (filtered.isEmpty) return _noSearchResultsState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _BuyerCard(buyer: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddBillScreen()),
          );
        },
        icon: const Icon(Icons.receipt_long, size: 28),
        label: Text(Strings.createBill, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.inkSoft),
            const SizedBox(height: 16),
            Text(Strings.noBuyers, style: const TextStyle(fontSize: 18, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _noSearchResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.inkSoft),
            const SizedBox(height: 16),
            Text('कुछ नहीं मिला', style: const TextStyle(fontSize: 18, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(Strings.errorOccurred, style: const TextStyle(fontSize: 18, color: AppColors.danger)),
          ],
        ),
      ),
    );
  }
}

class _BuyerCard extends StatelessWidget {
  final Buyer buyer;

  const _BuyerCard({required this.buyer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BuyerDetailScreen(buyer: buyer)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  buyer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
