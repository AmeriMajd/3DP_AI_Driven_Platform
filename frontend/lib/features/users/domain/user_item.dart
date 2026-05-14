class UserItem {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final int jobsCount;

  const UserItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.jobsCount,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) => UserItem(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        jobsCount: json['jobs_count'] as int,
      );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}
