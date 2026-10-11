import '../../../core/models/bill.dart';
import '../../../core/models/hisab.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';
import '../models/hisab_date_filter.dart';

enum HisabSort { newest, oldest }

class HisabRepository {
  static Map<String, dynamic> _dateParams(HisabDateFilter filter) => {
        if (filter.dateFrom != null) 'dateFrom': filter.dateFrom!.toUtc().toIso8601String(),
        if (filter.dateTo != null) 'dateTo': filter.dateTo!.toUtc().toIso8601String(),
      };

  static String _rangeCacheKey(HisabDateFilter filter) => filter.cacheKey;

  static Future<HisabSummary> fetchSummary({
    required String businessId,
    required HisabDateFilter filter,
  }) {
    final key = 'hisab:summary:$businessId:${_rangeCacheKey(filter)}';
    return LocalCacheService.fetchWithFallback<HisabSummary>(
      key: key,
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/dashboard',
          queryParameters: _dateParams(filter),
        );
        return HisabSummary.fromJson(Map<String, dynamic>.from(response.data as Map));
      },
      toJson: (summary) => {
        'totals': {
          'totalBilled': summary.totalBilled,
          'totalDue': summary.totalDue,
          'totalReceived': summary.totalReceived,
        },
        'topBuyers': summary.topBuyers.map((entry) => entry.toJson()).toList(),
        'topProducts': summary.topProducts.map((entry) => entry.toJson()).toList(),
      },
      fromJson: HisabSummary.fromJson,
    );
  }

  static Future<List<HisabRankEntry>> fetchRankings({
    required String businessId,
    required HisabDateFilter filter,
    required String kind,
  }) async {
    final key = 'hisab:rankings:$businessId:$kind:${_rangeCacheKey(filter)}';
    return LocalCacheService.fetchListWithFallback<HisabRankEntry>(
      key: key,
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/dashboard/rankings',
          queryParameters: {..._dateParams(filter), 'kind': kind},
        );
        return (response.data as List)
            .map((entry) => HisabRankEntry.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList();
      },
      toJson: (entry) => entry.toJson(),
      fromJson: HisabRankEntry.fromJson,
    );
  }

  static Future<List<Bill>> fetchBills({
    required String businessId,
    required HisabDateFilter filter,
    required HisabSort sort,
    bool unpaidOnly = false,
  }) async {
    final key = 'hisab:bills:$businessId:${filter.cacheKey}:${sort.name}:$unpaidOnly';
    return LocalCacheService.fetchListWithFallback<Bill>(
      key: key,
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/bills',
          queryParameters: {
            ..._dateParams(filter),
            'sort': sort.name,
            if (unpaidOnly) 'paid': 'false',
          },
        );
        return (response.data as List)
            .map((entry) => Bill.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList();
      },
      toJson: billToHisabJson,
      fromJson: Bill.fromJson,
    );
  }

  static Future<List<HisabPaymentRecord>> fetchPayments({
    required String businessId,
    required HisabDateFilter filter,
    required HisabSort sort,
  }) async {
    final key = 'hisab:payments:$businessId:${filter.cacheKey}:${sort.name}';
    return LocalCacheService.fetchListWithFallback<HisabPaymentRecord>(
      key: key,
      fetch: () async {
        final response = await ApiClient.instance.get(
          '/businesses/$businessId/deposits',
          queryParameters: {..._dateParams(filter), 'sort': sort.name},
        );
        return (response.data as List)
            .map((entry) => HisabPaymentRecord.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList();
      },
      toJson: (payment) => payment.toJson(),
      fromJson: HisabPaymentRecord.fromJson,
    );
  }
}
