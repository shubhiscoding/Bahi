import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bill.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/bill_repository.dart';
import 'buyer_providers.dart';

/// Input for creating a bill (Phase 8 §D/§F).
class CreateBillInput {
  final String buyerId;
  final DateTime billDate;
  final List<BillLineInput> items;
  final bool markPaidNow;

  CreateBillInput({
    required this.buyerId,
    required this.billDate,
    required this.items,
    required this.markPaidNow,
  });
}

final createBillProvider =
    FutureProvider.autoDispose.family<Bill, CreateBillInput>((ref, input) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');

  final bill = await BillRepository.createBill(
    businessId: business.id,
    buyerId: input.buyerId,
    billDate: input.billDate,
    items: input.items,
    markPaidNow: input.markPaidNow,
  );

  // A new bill changes stock (item quantities) and the buyer's totals —
  // refresh both rather than waiting for the next natural refetch.
  ref.invalidate(buyersProvider);
  return bill;
});

final billDetailProvider = FutureProvider.autoDispose.family<Bill, String>((ref, billId) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return BillRepository.fetchBillDetail(businessId: business.id, billId: billId);
});

/// Filters for the buyer detail page's bill history (Phase 8 §G).
/// Equality/hashCode overridden so Riverpod's family caching treats two
/// identical filter sets as the same query.
class BillsForBuyerQuery {
  final String buyerId;
  final bool? paid;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  BillsForBuyerQuery({required this.buyerId, this.paid, this.dateFrom, this.dateTo});

  @override
  bool operator ==(Object other) =>
      other is BillsForBuyerQuery &&
      other.buyerId == buyerId &&
      other.paid == paid &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(buyerId, paid, dateFrom, dateTo);
}

final billsForBuyerProvider =
    FutureProvider.autoDispose.family<List<Bill>, BillsForBuyerQuery>((ref, query) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return BillRepository.fetchBillsForBuyer(
    businessId: business.id,
    buyerId: query.buyerId,
    paid: query.paid,
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
  );
});

final addPaymentProvider =
    FutureProvider.autoDispose.family<void, ({String billId, double amount})>((ref, input) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  await BillRepository.addPayment(
    businessId: business.id,
    billId: input.billId,
    amount: input.amount,
  );
  ref.invalidate(billDetailProvider(input.billId));
});
