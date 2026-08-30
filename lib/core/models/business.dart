class Business {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final DateTime createdAt;

  Business({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.createdAt,
  });

  // Backend (Node/Express + Prisma) returns camelCase JSON.
  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['ownerId'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'inviteCode': inviteCode,
        'createdAt': createdAt.toIso8601String(),
      };
}

class BusinessMember {
  final String businessId;
  final String userId;
  final String role; // 'owner' or 'member'
  final String fullName;
  final DateTime joinedAt;

  BusinessMember({
    required this.businessId,
    required this.userId,
    required this.role,
    required this.fullName,
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  // Backend's GET /businesses/:id/members already joins profile names
  // server-side, so fullName arrives directly (no separate lookup needed).
  factory BusinessMember.fromJson(Map<String, dynamic> json) {
    return BusinessMember(
      businessId: json['businessId'] ?? '',
      userId: json['userId'] ?? '',
      role: json['role'] ?? 'member',
      fullName: json['fullName'] ?? '?',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }
}
