import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/deposit.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/deposit_repository.dart';

/// Filters for the buyer detail page's जमा (deposits) list (Phase 10) —
/// same equality/hashCode-override shape as BillsForBuyerQuery so
/// Riverpod's family caching treats identical filter sets as one query.
/// No `paid` filter — not a meaningful concept for a deposit.
class DepositsForBuyerQuery {
  final String buyerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  DepositsForBuyerQuery({required this.buyerId, this.dateFrom, this.dateTo});

  @override
  bool operator ==(Object other) =>
      other is DepositsForBuyerQuery &&
      other.buyerId == buyerId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(buyerId, dateFrom, dateTo);
}

final depositsForBuyerProvider =
    FutureProvider.autoDispose.family<List<Deposit>, DepositsForBuyerQuery>((ref, query) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return DepositRepository.fetchDepositsForBuyer(
    businessId: business.id,
    buyerId: query.buyerId,
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
  );
});

final depositDetailProvider =
    FutureProvider.autoDispose.family<Deposit, String>((ref, depositId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return DepositRepository.fetchDepositDetail(businessId: business.id, depositId: depositId);
});
