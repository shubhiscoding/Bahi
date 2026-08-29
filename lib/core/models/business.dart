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

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['owner_id'] ?? '',
      inviteCode: json['invite_code'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'invite_code': inviteCode,
        'created_at': createdAt.toIso8601String(),
      };
}

class BusinessMember {
  final String businessId;
  final String userId;
  final String role; // 'owner' or 'member'
  final DateTime joinedAt;

  BusinessMember({
    required this.businessId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory BusinessMember.fromJson(Map<String, dynamic> json) {
    return BusinessMember(
      businessId: json['business_id'] ?? '',
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'user_id': userId,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
      };
}
