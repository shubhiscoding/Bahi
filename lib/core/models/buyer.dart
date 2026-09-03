/// A buyer this business sells to — strictly per-business (Phase 8 §C).
class Buyer {
  final String id;
  final String name;
  final DateTime createdAt;
  // Most recent bill date, if any — drives the buyer picker's recency
  // sort (Phase 8 §E). Null if this buyer has never been billed.
  final DateTime? lastBilledAt;

  Buyer({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastBilledAt,
  });

  factory Buyer.fromJson(Map<String, dynamic> json) {
    return Buyer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      lastBilledAt: json['lastBilledAt'] != null ? DateTime.parse(json['lastBilledAt']) : null,
    );
  }
}

/// The buyer "about" page's aggregates (Phase 8 §G).
class BuyerDetail {
  final String id;
  final String name;
  final DateTime createdAt;
  final double totalBilled;
  final double totalPaid;
  final double totalDue;

  BuyerDetail({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.totalBilled,
    required this.totalPaid,
    required this.totalDue,
  });

  factory BuyerDetail.fromJson(Map<String, dynamic> json) {
    return BuyerDetail(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      totalBilled: (json['totalBilled'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
      totalDue: (json['totalDue'] as num?)?.toDouble() ?? 0,
    );
  }
}
