/// One point in an item's price history — backs the price-tracker chart
/// on the item detail screen (Phase 7 §A/§B). A new point is only ever
/// recorded server-side when the price actually changes, not on every save.
class PriceHistoryPoint {
  final double price;
  final DateTime recordedAt;

  PriceHistoryPoint({required this.price, required this.recordedAt});

  // Prisma's Decimal serializes as a STRING, same as InventoryItem.price.
  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    return PriceHistoryPoint(
      price: _parsePrice(json['price']),
      recordedAt: DateTime.parse(json['recordedAt']),
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
