import 'employee.dart';
import 'user.dart';

/// Search, filter and paging state for the employee list.
class EmployeeQuery {
  const EmployeeQuery({
    this.search = '',
    this.departmentId,
    this.role,
    this.status,
    this.page = 1,
    this.limit = 10,
  });

  /// Special department filter value meaning "employees without a department".
  static const noDepartment = 'none';

  final String search;
  final String? departmentId;
  final UserRole? role;
  final EmployeeStatus? status;
  final int page;
  final int limit;

  bool get hasFilters => search.isNotEmpty || departmentId != null || role != null || status != null;

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (departmentId != null) 'department': departmentId,
        if (role != null) 'role': role!.name,
        if (status != null) 'status': status!.name,
      };

  static const Object _unset = Object();

  /// Nullable filters use a sentinel so `copyWith(role: null)` clears the filter
  /// while omitting `role` keeps the current value.
  EmployeeQuery copyWith({
    String? search,
    Object? departmentId = _unset,
    Object? role = _unset,
    Object? status = _unset,
    int? page,
  }) {
    return EmployeeQuery(
      search: search ?? this.search,
      departmentId: identical(departmentId, _unset) ? this.departmentId : departmentId as String?,
      role: identical(role, _unset) ? this.role : role as UserRole?,
      status: identical(status, _unset) ? this.status : status as EmployeeStatus?,
      page: page ?? this.page,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EmployeeQuery &&
      other.search == search &&
      other.departmentId == departmentId &&
      other.role == role &&
      other.status == status &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(search, departmentId, role, status, page, limit);
}
