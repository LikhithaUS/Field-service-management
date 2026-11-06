/// Roles match the backend's RBAC roles exactly.
enum UserRole {
  admin,
  manager,
  employee;

  static UserRole fromString(String? value) =>
      UserRole.values.firstWhere((r) => r.name == value, orElse: () => UserRole.employee);

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.manager => 'Manager',
        UserRole.employee => 'Employee',
      };
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.employeeId,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? employeeId;
  final bool isActive;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isEmployee => role == UserRole.employee;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] ?? json['_id']) as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.fromString(json['role'] as String?),
        employeeId: json['employeeId'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'employeeId': employeeId,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
      };
}
