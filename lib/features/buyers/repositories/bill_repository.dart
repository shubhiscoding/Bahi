import '../../../core/models/bill.dart';
import '../../../core/services/api_client.dart';

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
    final response = await ApiClient.instance.get('/businesses/$businessId/bills/$billId');
    return Bill.fromJson(response.data);
  }

  /// Feeds the buyer detail page's filterable bill history (Phase 8 §G).
  static Future<List<Bill>> fetchBillsForBuyer({
    required String businessId,
    required String buyerId,
    bool? paid,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await ApiClient.instance.get(
      '/businesses/$businessId/buyers/$buyerId/bills',
      queryParameters: {
        if (paid != null) 'paid': paid.toString(),
        if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
        if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      },
    );
    return (response.data as List).map((b) => Bill.fromJson(b)).toList();
  }

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
}
