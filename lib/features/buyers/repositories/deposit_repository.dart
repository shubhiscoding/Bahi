import '../../../core/models/deposit.dart';
import '../../../core/services/api_client.dart';

/// Deposits (Phase 10) — read-only; every deposit is created as a side
/// effect of BillRepository.addPayment/recordBuyerPayment, not directly.
class DepositRepository {
  /// Feeds the buyer detail page's जमा list.
  static Future<List<Deposit>> fetchDepositsForBuyer({
    required String businessId,
    required String buyerId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await ApiClient.instance.get(
      '/businesses/$businessId/buyers/$buyerId/deposits',
      queryParameters: {
        if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
        if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      },
    );
    return (response.data as List).map((d) => Deposit.fromJson(d)).toList();
  }

  static Future<Deposit> fetchDepositDetail({
    required String businessId,
    required String depositId,
  }) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/deposits/$depositId');
    return Deposit.fromJson(response.data);
  }
}
