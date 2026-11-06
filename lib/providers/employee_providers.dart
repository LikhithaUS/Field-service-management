import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/paginated.dart';
import '../models/user.dart';
import 'department_providers.dart';
import 'service_providers.dart';

/// Current search/filter/page state. Kept alive so filters survive leaving and
/// returning to the list.
final employeeQueryProvider = NotifierProvider<EmployeeQueryController, EmployeeQuery>(EmployeeQueryController.new);

class EmployeeQueryController extends Notifier<EmployeeQuery> {
  @override
  EmployeeQuery build() => const EmployeeQuery();

  // Changing any filter jumps back to page 1.
  void setSearch(String value) => state = state.copyWith(search: value.trim(), page: 1);
  void setDepartment(String? id) => state = state.copyWith(departmentId: id, page: 1);
  void setRole(UserRole? role) => state = state.copyWith(role: role, page: 1);
  void setStatus(EmployeeStatus? status) => state = state.copyWith(status: status, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void clear() => state = const EmployeeQuery();
}

/// The current page of employees; re-fetches automatically whenever the query changes.
final employeeListProvider = FutureProvider.autoDispose<Paginated<Employee>>((ref) {
  final query = ref.watch(employeeQueryProvider);
  return ref.watch(employeeServiceProvider).list(query);
});

final employeeDetailProvider = FutureProvider.autoDispose.family<Employee, String>((ref, id) {
  return ref.watch(employeeServiceProvider).get(id);
});

/// Call after creating/updating/deleting so every screen shows fresh data
/// (department employee counts change too).
void refreshEmployeeData(WidgetRef ref, {String? employeeId}) {
  ref.invalidate(employeeListProvider);
  ref.invalidate(departmentsProvider);
  if (employeeId != null) ref.invalidate(employeeDetailProvider(employeeId));
}
