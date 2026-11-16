import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/app.dart';
import 'package:fsm_app/models/attendance.dart';
import 'package:fsm_app/models/attendance_query.dart';
import 'package:fsm_app/models/department.dart';
import 'package:fsm_app/models/employee.dart';
import 'package:fsm_app/models/employee_query.dart';
import 'package:fsm_app/models/leave.dart';
import 'package:fsm_app/models/leave_query.dart';
import 'package:fsm_app/models/paginated.dart';
import 'package:fsm_app/models/task.dart';
import 'package:fsm_app/models/task_query.dart';
import 'package:fsm_app/models/user.dart';
import 'package:fsm_app/providers/service_providers.dart';
import 'package:fsm_app/services/api_service.dart';
import 'package:fsm_app/services/attendance_service.dart';
import 'package:fsm_app/services/auth_service.dart';
import 'package:fsm_app/services/department_service.dart';
import 'package:fsm_app/services/employee_service.dart';
import 'package:fsm_app/services/leave_service.dart';
import 'package:fsm_app/services/task_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockApiService extends Mock implements ApiService {}

class MockEmployeeService extends Mock implements EmployeeService {}

class MockDepartmentService extends Mock implements DepartmentService {}

class MockTaskService extends Mock implements TaskService {}

class MockAttendanceService extends Mock implements AttendanceService {}

class MockLeaveService extends Mock implements LeaveService {}

const adminUser = User(id: 'u1', name: 'Root Admin', email: 'root@example.com', role: UserRole.admin, employeeId: 'EMP-0001');
const managerUser = User(id: 'u2', name: 'Maya Manager', email: 'maya@example.com', role: UserRole.manager);
const employeeUser = User(id: 'u3', name: 'Eli Employee', email: 'eli@example.com', role: UserRole.employee);

const itDept = Department(id: 'd1', name: 'IT', description: 'Tech', employeeCount: 2);
const hrDept = Department(id: 'd2', name: 'HR', employeeCount: 0);

Employee makeEmployee(int n, {UserRole role = UserRole.employee, Department? department = itDept}) => Employee(
      id: 'e$n',
      employeeId: 'EMP-${n.toString().padLeft(4, '0')}',
      name: 'Person $n',
      email: 'person$n@example.com',
      designation: 'Technician',
      department: department,
      role: role,
      joiningDate: DateTime(2026, 1, n),
    );

PersonRef personFrom(User u) => PersonRef(id: u.id, name: u.name, email: u.email, role: u.role);

Task makeTask(
  int n, {
  User assignee = employeeUser,
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.medium,
  DateTime? dueDate,
}) =>
    Task(
      id: 't$n',
      taskNumber: 'TSK-${n.toString().padLeft(4, '0')}',
      title: 'Job $n',
      description: 'Details for job $n',
      location: 'Site $n',
      assignedTo: personFrom(assignee),
      assignedBy: personFrom(managerUser),
      status: status,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime(2026, 11, 1, 9, 30),
    );

LeaveRequest makeLeave(
  String id, {
  User requester = employeeUser,
  LeaveStatus status = LeaveStatus.pending,
  LeaveType type = LeaveType.casual,
  DateTime? start,
  DateTime? end,
  int days = 3,
}) {
  final s = start ?? DateTime.now().add(const Duration(days: 10));
  return LeaveRequest(
    id: id,
    user: personFrom(requester),
    leaveType: type,
    startDate: DateTime(s.year, s.month, s.day),
    endDate: end ?? DateTime(s.year, s.month, s.day + 2),
    days: days,
    reason: 'Family function',
    status: status,
    createdAt: DateTime(2026, 11, 10, 9),
  );
}

AttendanceHistory historyOf(List<AttendanceRecord> items, {AttendanceSummary summary = const AttendanceSummary(), int total = -1}) =>
    AttendanceHistory(page: pageOf(items, total: total), summary: summary);

Paginated<T> pageOf<T>(List<T> items, {int page = 1, int total = -1, int limit = 10}) {
  final t = total < 0 ? items.length : total;
  return Paginated(items: items, page: page, limit: limit, total: t, totalPages: (t / limit).ceil().clamp(1, 1 << 30));
}

class TestServices {
  final auth = MockAuthService();
  final employees = MockEmployeeService();
  final departments = MockDepartmentService();
  final tasks = MockTaskService();
  final attendance = MockAttendanceService();
  final leaves = MockLeaveService();

  TestServices({User? signedInAs}) {
    when(() => auth.currentUser()).thenAnswer((_) async => signedInAs);
    when(() => departments.list()).thenAnswer((_) async => [itDept, hrDept]);
  }
}

void registerTestFallbacks() {
  registerFallbackValue(const EmployeeQuery());
  registerFallbackValue(const TaskQuery());
  registerFallbackValue(TaskStatus.pending);
  registerFallbackValue(AttendanceQuery.today());
  registerFallbackValue(const LeaveQuery());
  registerFallbackValue(LeaveType.casual);
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(<String, dynamic>{});
}

/// Pumps the whole app (real router, real screens) with mocked services.
Future<void> pumpApp(WidgetTester tester, TestServices services, {Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(services.auth),
      apiServiceProvider.overrideWithValue(MockApiService()),
      employeeServiceProvider.overrideWithValue(services.employees),
      departmentServiceProvider.overrideWithValue(services.departments),
      taskServiceProvider.overrideWithValue(services.tasks),
      attendanceServiceProvider.overrideWithValue(services.attendance),
      leaveServiceProvider.overrideWithValue(services.leaves),
    ],
    child: const ServiceHubApp(),
  ));
  await tester.pumpAndSettle();
}
