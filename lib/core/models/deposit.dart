/// One bill this deposit settled, and how much of the deposit went to it
/// (Phase 10) — only populated by the deposit detail endpoint.
class DepositBillAllocation {
  final String billId;
  final DateTime billDate;
  final double billTotal;
  final double amount;

  DepositBillAllocation({
    required this.billId,
    required this.billDate,
    required this.billTotal,
    required this.amount,
  });

  factory DepositBillAllocation.fromJson(Map<String, dynamic> json) {
    return DepositBillAllocation(
      billId: json['billId'] ?? '',
      billDate: json['billDate'] != null ? DateTime.parse(json['billDate']) : DateTime.now(),
      billTotal: _parseDecimal(json['billTotal']),
      amount: _parseDecimal(json['amount']),
    );
  }
}

/// One payment EVENT (Phase 10) — a buyer handing over money, regardless
/// of whether it settled one bill or several. `bills` is only populated
/// by the detail endpoint (GET /deposits/:id), same "list is lighter,
/// detail is fuller" convention as Bill.
class Deposit {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String recordedByName;
  final List<DepositBillAllocation>? bills;

  Deposit({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.recordedByName,
    this.bills,
  });

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id'] ?? '',
      amount: _parseDecimal(json['amount']),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : DateTime.now(),
      recordedByName: json['recordedByName'] ?? '?',
      bills: json['bills'] != null
          ? (json['bills'] as List).map((b) => DepositBillAllocation.fromJson(b)).toList()
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
