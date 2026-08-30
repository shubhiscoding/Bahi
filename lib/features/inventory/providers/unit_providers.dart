import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/unit.dart';
import '../../business/providers/business_providers.dart';
import '../repositories/unit_repository.dart';

/// This business's own linked units (strictly per-business, no
/// cross-business suggestions — confirmed requirement).
final unitsProvider = FutureProvider<List<Unit>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return UnitRepository.listUnits(business.id);
});

/// Adds a new unit to the current business's list.
final addUnitProvider = FutureProvider.autoDispose.family<Unit, String>((ref, name) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw Exception('No business selected');
  return UnitRepository.addUnit(business.id, name);
});
