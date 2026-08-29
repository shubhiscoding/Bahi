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

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price'] ?? 0.0,
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? 'piece',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      updatedBy: json['updated_by'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'unit': unit,
        'updated_at': updatedAt.toIso8601String(),
        'updated_by': updatedBy,
        'created_at': createdAt.toIso8601String(),
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
