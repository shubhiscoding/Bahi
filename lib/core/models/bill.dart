/// One product line on a bill (Phase 8 §D). itemName is only present when
/// fetched via the bill detail endpoint (a joined field), not the list.
class BillLineItem {
  final String itemId;
  final String? itemName;
  final int quantity;
  final double price;

  BillLineItem({
    required this.itemId,
    this.itemName,
    required this.quantity,
    required this.price,
  });

  factory BillLineItem.fromJson(Map<String, dynamic> json) {
    return BillLineItem(
      itemId: json['itemId'] ?? '',
      itemName: json['itemName'],
      quantity: json['quantity'] ?? 0,
      price: _parseDecimal(json['price']),
    );
  }

  double get subtotal => quantity * price;
}

/// One payment recorded against a bill (Phase 8 §D) — only populated by
/// the detail endpoint (GET /bills/:id), same as items/buyerName.
class BillPaymentRecord {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String recordedByName;

  BillPaymentRecord({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.recordedByName,
  });

  factory BillPaymentRecord.fromJson(Map<String, dynamic> json) {
    return BillPaymentRecord(
      id: json['id'] ?? '',
      amount: _parseDecimal(json['amount']),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : DateTime.now(),
      recordedByName: json['recordedByName'] ?? '?',
    );
  }
}

/// One bill/sale to a buyer. `items`/`buyerName`/`createdByName`/
/// `payments` are only populated by the detail endpoint (GET /bills/:id)
/// — the list endpoint (GET /buyers/:id/bills) returns the lighter shape
/// used for the buyer "about" page's scrollable history.
class Bill {
  final String id;
  final String buyerId;
  final String? buyerName;
  final DateTime billDate;
  final double total;
  final double paid;
  final double due;
  final String? createdByName;
  final DateTime createdAt;
  final List<BillLineItem>? items;
  final List<BillPaymentRecord>? payments;

  Bill({
    required this.id,
    required this.buyerId,
    this.buyerName,
    required this.billDate,
    required this.total,
    required this.paid,
    required this.due,
    this.createdByName,
    required this.createdAt,
    this.items,
    this.payments,
  });

  bool get isPaid => due <= 0;

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? '',
      buyerId: json['buyerId'] ?? '',
      buyerName: json['buyerName'] ?? json['buyer']?['name'],
      billDate: json['billDate'] != null ? DateTime.parse(json['billDate']) : DateTime.now(),
      total: _parseDecimal(json['total']),
      paid: (json['paid'] as num?)?.toDouble() ?? 0,
      due: (json['due'] as num?)?.toDouble() ?? 0,
      createdByName: json['createdByName'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      items: json['items'] != null
          ? (json['items'] as List).map((i) => BillLineItem.fromJson(i)).toList()
          : null,
      payments: json['payments'] != null
          ? (json['payments'] as List).map((p) => BillPaymentRecord.fromJson(p)).toList()
          : null,
    );
  }
}

// Prisma's Decimal serializes as a STRING — same guard used throughout
// the rest of the app (see inventory_item.dart's _parsePrice).
double _parseDecimal(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
