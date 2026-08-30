class InventoryItem {
  final String id;
  final String businessId;
  final String name;
  final double price;
  final int quantity;
  final String unit; // 'piece', 'kg', 'litre', 'dozen', etc.
  final DateTime updatedAt;
  final String updatedBy; // user ID
  final DateTime createdAt;

  InventoryItem({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.updatedAt,
    required this.updatedBy,
    required this.createdAt,
  });

  // Backend (Node/Express + Prisma) returns camelCase JSON. Prisma's
  // Decimal type serializes price as a STRING (not a number), so it's
  // parsed accordingly here.
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      businessId: json['businessId'] ?? '',
      name: json['name'] ?? '',
      price: _parsePrice(json['price']),
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? 'piece',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      updatedBy: json['updatedBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'unit': unit,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  InventoryItem copyWith({
    String? id,
    String? businessId,
    String? name,
    double? price,
    int? quantity,
    String? unit,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
