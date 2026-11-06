import 'department.dart';
import 'user.dart';

enum EmployeeStatus {
  active,
  inactive;

  static EmployeeStatus fromString(String? value) =>
      EmployeeStatus.values.firstWhere((s) => s.name == value, orElse: () => EmployeeStatus.active);

  String get label => switch (this) {
        EmployeeStatus.active => 'Active',
        EmployeeStatus.inactive => 'Inactive',
      };
}

class Employee {
  const Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    this.phone = '',
    this.designation = '',
    this.department,
    this.role = UserRole.employee,
    this.joiningDate,
    this.status = EmployeeStatus.active,
    this.profileImage,
  });

  final String id;
  final String employeeId; // human-friendly, e.g. EMP-0001
  final String name;
  final String email;
  final String phone;
  final String designation;
  final Department? department;
  final UserRole role;
  final DateTime? joiningDate;
  final EmployeeStatus status;
  final String? profileImage;

  bool get isActive => status == EmployeeStatus.active;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: (json['id'] ?? json['_id']) as String,
        employeeId: json['employeeId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        designation: json['designation'] as String? ?? '',
        department: json['department'] == null ? null : Department.fromJson(json['department'] as Object),
        role: UserRole.fromString(json['role'] as String?),
        joiningDate: json['joiningDate'] == null ? null : DateTime.tryParse(json['joiningDate'] as String)?.toLocal(),
        status: EmployeeStatus.fromString(json['status'] as String?),
        profileImage: json['profileImage'] as String?,
      );
}
