class Department {
  const Department({required this.id, required this.name, this.description = '', this.employeeCount = 0});

  final String id;
  final String name;
  final String description;
  final int employeeCount;

  /// Accepts a full department object, the `{id, name}` shape embedded in employees,
  /// or a bare id string.
  factory Department.fromJson(Object json) {
    if (json is String) return Department(id: json, name: '');
    final map = json as Map<String, dynamic>;
    return Department(
      id: (map['id'] ?? map['_id']) as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      employeeCount: (map['employeeCount'] as num?)?.toInt() ?? 0,
    );
  }
}
