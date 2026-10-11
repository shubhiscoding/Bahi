import 'bill.dart';

class HisabSummary {
  final double totalBilled;
  final double totalDue;
  final double totalReceived;
  final List<HisabRankEntry> topBuyers;
  final List<HisabRankEntry> topProducts;

  const HisabSummary({
    required this.totalBilled,
    required this.totalDue,
    required this.totalReceived,
    required this.topBuyers,
    required this.topProducts,
  });

  factory HisabSummary.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? const {});
    return HisabSummary(
      totalBilled: _number(totals['totalBilled']),
      totalDue: _number(totals['totalDue']),
      totalReceived: _number(totals['totalReceived']),
      topBuyers: _rankEntries(json['topBuyers']),
      topProducts: _rankEntries(json['topProducts']),
    );
  }
}

class HisabRankEntry {
  final String id;
  final String name;
  final double amount;
  final int quantity;

  const HisabRankEntry({required this.id, required this.name, required this.amount, this.quantity = 0});

  factory HisabRankEntry.fromJson(Map<String, dynamic> json) => HisabRankEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        amount: _number(json['amount']),
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'quantity': quantity,
      };
}

class HisabPaymentRecord {
  final String id;
  final String? depositId;
  final String? billId;
  final String buyerId;
  final String buyerName;
  final double amount;
  final DateTime paidAt;
  final String recordedByName;
  final bool legacy;

  const HisabPaymentRecord({
    required this.id,
    required this.depositId,
    required this.billId,
    required this.buyerId,
    required this.buyerName,
    required this.amount,
    required this.paidAt,
    required this.recordedByName,
    required this.legacy,
  });

  factory HisabPaymentRecord.fromJson(Map<String, dynamic> json) => HisabPaymentRecord(
        id: json['id'] as String? ?? '',
        depositId: json['depositId'] as String?,
        billId: json['billId'] as String?,
        buyerId: json['buyerId'] as String? ?? '',
        buyerName: json['buyerName'] as String? ?? '',
        amount: _number(json['amount']),
        paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : DateTime.now(),
        recordedByName: json['recordedByName'] as String? ?? '?',
        legacy: json['legacy'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'depositId': depositId,
        'billId': billId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'amount': amount,
        'paidAt': paidAt.toIso8601String(),
        'recordedByName': recordedByName,
        'legacy': legacy,
      };
}

List<HisabRankEntry> _rankEntries(dynamic value) => value is List
    ? value.map((entry) => HisabRankEntry.fromJson(Map<String, dynamic>.from(entry as Map))).toList()
    : const [];

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> billToHisabJson(Bill bill) => {
      'id': bill.id,
      'buyerId': bill.buyerId,
      'buyerName': bill.buyerName,
      'billDate': bill.billDate.toIso8601String(),
      'total': bill.total,
      'paid': bill.paid,
      'due': bill.due,
      'createdByName': bill.createdByName,
      'createdAt': bill.createdAt.toIso8601String(),
    };
