import '../../../core/models/bill.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';

/// Line item input for creating a bill (Phase 8 §D/§F).
class BillLineInput {
  final String itemId;
  final int quantity;
  final double price;

  BillLineInput({required this.itemId, required this.quantity, required this.price});

  Map<String, dynamic> toJson() => {'itemId': itemId, 'quantity': quantity, 'price': price};
}

class BillRepository {
  static Future<Bill> createBill({
    required String businessId,
    required String buyerId,
    required DateTime billDate,
    required List<BillLineInput> items,
    required bool markPaidNow,
  }) async {
    final response = await ApiClient.instance.post(
      '/businesses/$businessId/bills',
      data: {
        'buyerId': buyerId,
        'billDate': billDate.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'markPaidNow': markPaidNow,
      },
    );
    return Bill.fromJson(response.data);
  }

  static Future<Bill> fetchBillDetail({required String businessId, required String billId}) async {
    return LocalCacheService.fetchWithFallback<Bill>(
      key: 'billDetail:$businessId:$billId',
      fetch: () async {
        final response = await ApiClient.instance.get('/businesses/$businessId/bills/$billId');
        return Bill.fromJson(response.data);
      },
      toJson: _billToJson,
      fromJson: Bill.fromJson,
    );
  }

  /// Feeds the buyer detail page's filterable bill history (Phase 8 §G).
  /// Phase 12 §C: the buyer detail screen always calls this unfiltered
  /// and filters client-side (paid/dateFrom/dateTo below are currently
  /// always null in practice) — so the cache key intentionally ignores
  /// the filter params too. If a caller ever does pass server-side
  /// filters, the offline fallback still returns the last cached
  /// *unfiltered* list rather than nothing.
  static Future<List<Bill>> fetchBillsForBuyer({
    required String businessId,
    required String buyerId,
    bool? paid,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return LocalCacheService.fetchListWithFallback<Bill>(
      key: 'bills:$businessId:$buyerId',
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/buyers/$buyerId/bills',
          queryParameters: {
            if (paid != null) 'paid': paid.toString(),
            if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
            if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
          },
        );
        return (response.data as List).map((b) => Bill.fromJson(b)).toList();
      },
      toJson: _billToJson,
      fromJson: Bill.fromJson,
    );
  }

  static Map<String, dynamic> _billToJson(Bill b) => {
        'id': b.id,
        'buyerId': b.buyerId,
        'buyerName': b.buyerName,
        'billDate': b.billDate.toIso8601String(),
        'total': b.total,
        'paid': b.paid,
        'due': b.due,
        'createdByName': b.createdByName,
        'createdAt': b.createdAt.toIso8601String(),
        'items': b.items
            ?.map((i) => {
                  'itemId': i.itemId,
                  'itemName': i.itemName,
                  'quantity': i.quantity,
                  'price': i.price,
                })
            .toList(),
        'payments': b.payments
            ?.map((p) => {
                  'id': p.id,
                  'amount': p.amount,
                  'paidAt': p.paidAt.toIso8601String(),
                  'recordedByName': p.recordedByName,
                })
            .toList(),
      };

  static Future<void> addPayment({
    required String businessId,
    required String billId,
    required double amount,
  }) async {
    await ApiClient.instance.post(
      '/businesses/$businessId/bills/$billId/payments',
      data: {'amount': amount},
    );
  }

  /// Buyer-level "record payment" (Phase 9) — server allocates this one
  /// amount across the buyer's outstanding bills, oldest first.
  static Future<void> recordBuyerPayment({
    required String businessId,
    required String buyerId,
    required double amount,
  }) async {
    await ApiClient.instance.post(
      '/businesses/$businessId/buyers/$buyerId/payments',
      data: {'amount': amount},
    );
  }
}
