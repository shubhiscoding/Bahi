import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bill.dart';
import '../../../core/models/hisab.dart';
import '../../business/providers/business_providers.dart';
import '../models/hisab_date_filter.dart';
import '../repositories/hisab_repository.dart';

final hisabSummaryProvider =
    FutureProvider.autoDispose.family<HisabSummary, HisabDateFilter>((ref, filter) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return HisabRepository.fetchSummary(businessId: business.id, filter: filter);
});

class HisabBillsQuery {
  final HisabDateFilter filter;
  final HisabSort sort;
  final bool unpaidOnly;

  const HisabBillsQuery({required this.filter, required this.sort, this.unpaidOnly = false});

  @override
  bool operator ==(Object other) =>
      other is HisabBillsQuery &&
      other.filter == filter &&
      other.sort == sort &&
      other.unpaidOnly == unpaidOnly;

  @override
  int get hashCode => Object.hash(filter, sort, unpaidOnly);
}

final hisabBillsProvider =
    FutureProvider.autoDispose.family<List<Bill>, HisabBillsQuery>((ref, query) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return HisabRepository.fetchBills(
    businessId: business.id,
    filter: query.filter,
    sort: query.sort,
    unpaidOnly: query.unpaidOnly,
  );
});

final hisabPaymentsProvider = FutureProvider.autoDispose
    .family<List<HisabPaymentRecord>, ({HisabDateFilter filter, HisabSort sort})>((ref, query) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return HisabRepository.fetchPayments(
    businessId: business.id,
    filter: query.filter,
    sort: query.sort,
  );
});

final hisabRankingsProvider = FutureProvider.autoDispose.family<
    List<HisabRankEntry>, ({HisabDateFilter filter, String kind})>((ref, query) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return HisabRepository.fetchRankings(
    businessId: business.id,
    filter: query.filter,
    kind: query.kind,
  );
});
