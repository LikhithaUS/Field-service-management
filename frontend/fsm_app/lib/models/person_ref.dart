import 'user.dart';

/// The small slice of a user that the backend populates on references
/// (task assignees, comment authors, attendance records).
class PersonRef {
  const PersonRef({required this.id, required this.name, this.email = '', this.role = UserRole.employee, this.employeeId});

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? employeeId;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// A populated reference is an object; if the account was deleted it can be null.
  static PersonRef? fromJson(Object? json) {
    if (json is! Map) return null;
    return PersonRef(
      id: (json['id'] ?? json['_id']) as String,
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      employeeId: json['employeeId'] as String?,
    );
  }
}
