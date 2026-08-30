import '../../../core/models/unit.dart';
import '../../../core/services/api_client.dart';

class UnitRepository {
  static Future<List<Unit>> listUnits(String businessId) async {
    final response = await ApiClient.instance.get('/businesses/$businessId/units');
    return (response.data as List).map((u) => Unit.fromJson(u)).toList();
  }

  static Future<Unit> addUnit(String businessId, String name) async {
    final response = await ApiClient.instance.post(
      '/businesses/$businessId/units',
      data: {'name': name},
    );
    return Unit.fromJson(response.data);
  }
}
