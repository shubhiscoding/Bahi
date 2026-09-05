import '../../../core/models/deposit.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';

/// Deposits (Phase 10) — read-only; every deposit is created as a side
/// effect of BillRepository.addPayment/recordBuyerPayment, not directly.
class DepositRepository {
  /// Feeds the buyer detail page's जमा list. Phase 12 §C: same as
  /// BillRepository.fetchBillsForBuyer — the screen always calls this
  /// unfiltered and filters client-side, so the cache key intentionally
  /// ignores dateFrom/dateTo.
  static Future<List<Deposit>> fetchDepositsForBuyer({
    required String businessId,
    required String buyerId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return LocalCacheService.fetchListWithFallback<Deposit>(
      key: 'deposits:$businessId:$buyerId',
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/buyers/$buyerId/deposits',
          queryParameters: {
            if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
            if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
          },
        );
        return (response.data as List).map((d) => Deposit.fromJson(d)).toList();
      },
      toJson: _depositToJson,
      fromJson: Deposit.fromJson,
    );
  }

  static Future<Deposit> fetchDepositDetail({
    required String businessId,
    required String depositId,
  }) async {
    return LocalCacheService.fetchWithFallback<Deposit>(
      key: 'depositDetail:$businessId:$depositId',
      fetch: () async {
        final response =
            await ApiClient.instance.get('/businesses/$businessId/deposits/$depositId');
        return Deposit.fromJson(response.data);
      },
      toJson: _depositToJson,
      fromJson: Deposit.fromJson,
    );
  }

  static Map<String, dynamic> _depositToJson(Deposit d) => {
        'id': d.id,
        'amount': d.amount,
        'paidAt': d.paidAt.toIso8601String(),
        'recordedByName': d.recordedByName,
        'bills': d.bills
            ?.map((b) => {
                  'billId': b.billId,
                  'billDate': b.billDate.toIso8601String(),
                  'billTotal': b.billTotal,
                  'amount': b.amount,
                })
            .toList(),
      };
}
