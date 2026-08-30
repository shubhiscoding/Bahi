class User {
  final String id;
  final String fullName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.createdAt,
  });

  // Backend (Node/Express + Prisma) returns camelCase JSON, not the
  // snake_case Supabase's PostgREST used to return.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'createdAt': createdAt.toIso8601String(),
      };
}
