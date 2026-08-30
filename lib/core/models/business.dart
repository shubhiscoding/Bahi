class Business {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  Business({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  // Backend (Node/Express + Prisma) returns camelCase JSON.
  // Note: invite codes are ephemeral (5-min, single-use — see
  // InviteCode below) and NOT part of this model anymore.
  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['ownerId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// An ephemeral, OTP-style invite code: valid 5 minutes, single-use.
/// Generated on demand (POST /businesses/:id/invite-code) right when the
/// owner taps "Share" — never stored/displayed as a permanent value.
class InviteCode {
  final String code;
  final DateTime expiresAt;

  InviteCode({required this.code, required this.expiresAt});

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      code: json['code'] ?? '',
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
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
