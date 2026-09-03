/// One point in an item's price history — backs the price-tracker chart
/// AND the price-history list on the item detail screen. A new point is
/// only ever recorded server-side when the price actually changes, not
/// on every save.
class PriceHistoryPoint {
  final double price;
  final DateTime recordedAt;
  // Who made the change that produced this point. Null on rows written
  // before this column existed (no backfill) — show '?' in that case,
  // same fallback pattern used everywhere else "edited by" is shown.
  final String? editedByName;

  PriceHistoryPoint({
    required this.price,
    required this.recordedAt,
    this.editedByName,
  });

  // Prisma's Decimal serializes as a STRING, same as InventoryItem.price.
  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      price: _parsePrice(json['price']),
      recordedAt: DateTime.parse(json['recordedAt']),
      editedByName: json['editedByName'],
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
