class ProfileStats {
  final int filesUploaded;
  final int recommendationsCount;
  final int jobsSubmitted;

  const ProfileStats({
    required this.filesUploaded,
    required this.recommendationsCount,
    required this.jobsSubmitted,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        filesUploaded: json['files_uploaded'] as int? ?? 0,
        recommendationsCount: json['recommendations_count'] as int? ?? 0,
        jobsSubmitted: json['jobs_submitted'] as int? ?? 0,
      );
}

class ProfileUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final ProfileStats stats;

  const ProfileUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    required this.stats,
  });

  factory ProfileUser.fromJson(Map<String, dynamic> json) => ProfileUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastLogin: json['last_login'] != null
            ? DateTime.parse(json['last_login'] as String)
            : null,
        stats: ProfileStats.fromJson(json['stats'] as Map<String, dynamic>),
      );

  ProfileUser copyWith({String? fullName, String? email}) => ProfileUser(
        id: id,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        role: role,
        createdAt: createdAt,
        lastLogin: lastLogin,
        stats: stats,
      );
}
