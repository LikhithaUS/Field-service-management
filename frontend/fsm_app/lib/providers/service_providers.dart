import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/announcement_service.dart';
import '../services/api_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/department_service.dart';
import '../services/employee_service.dart';
import '../services/leave_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';

/// Dependency injection: services are exposed as providers so they can be
/// swapped for fakes in tests via `ProviderScope(overrides: [...])`.
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(storage: ref.watch(storageServiceProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    api: ref.watch(apiServiceProvider),
    storage: ref.watch(storageServiceProvider),
  ),
);

final employeeServiceProvider = Provider<EmployeeService>((ref) => EmployeeService(ref.watch(apiServiceProvider)));

final departmentServiceProvider = Provider<DepartmentService>(
  (ref) => DepartmentService(ref.watch(apiServiceProvider)),
);

final taskServiceProvider = Provider<TaskService>((ref) => TaskService(ref.watch(apiServiceProvider)));

final attendanceServiceProvider = Provider<AttendanceService>(
  (ref) => AttendanceService(ref.watch(apiServiceProvider)),
);

final leaveServiceProvider = Provider<LeaveService>((ref) => LeaveService(ref.watch(apiServiceProvider)));

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiServiceProvider)),
);

final announcementServiceProvider = Provider<AnnouncementService>(
  (ref) => AnnouncementService(ref.watch(apiServiceProvider)),
);
