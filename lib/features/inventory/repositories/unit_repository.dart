import '../../../core/models/unit.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/local_cache_service.dart';

class UnitRepository {
  static Future<List<Unit>> listUnits(String businessId) async {
    return LocalCacheService.fetchListWithFallback<Unit>(
      key: 'units:$businessId',
      fetch: () async {
        final response = await ApiClient.instance.get('/businesses/$businessId/units');
        return (response.data as List).map((u) => Unit.fromJson(u)).toList();
      },
      toJson: (u) => {'id': u.id, 'name': u.name},
      fromJson: Unit.fromJson,
    );
  }

  static Future<Unit> addUnit(String businessId, String name) async {
    final response = await ApiClient.instance.post(
      '/businesses/$businessId/units',
      data: {'name': name},
    );
    return Unit.fromJson(response.data);
  }
}
