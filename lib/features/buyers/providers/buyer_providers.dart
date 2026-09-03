import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/buyer.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/buyer_repository.dart';

/// Live stream of buyers for the current business (Phase 8 §C) — same
/// fetch+socket-patch shape as inventoryItemsProvider.
final buyersProvider = StreamProvider<List<Buyer>>((ref) {
  final businessAsync = ref.watch(currentBusinessProvider);

  return businessAsync.when(
    data: (business) {
      if (business == null) return Stream.value(<Buyer>[]);
      return BuyerRepository.watchBuyers(business.id);
    },
    loading: () => Stream.value(<Buyer>[]),
    error: (err, stack) => Stream.value(<Buyer>[]),
  );
});

/// Creates a new buyer — used by the buyer picker's inline "add new"
/// modal (Phase 8 §E).
final createBuyerProvider = FutureProvider.autoDispose.family<Buyer, String>((ref, name) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return BuyerRepository.createBuyer(businessId: business.id, name: name);
});

/// The buyer "about" page's aggregates (Phase 8 §G).
final buyerDetailProvider =
    FutureProvider.autoDispose.family<BuyerDetail, String>((ref, buyerId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return BuyerRepository.fetchBuyerDetail(businessId: business.id, buyerId: buyerId);
});
