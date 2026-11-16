import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../screens/announcements/announcement_details_screen.dart';
import '../screens/announcements/announcement_form_screen.dart';
import '../screens/announcements/announcement_list_screen.dart';
import '../screens/attendance/attendance_report_screen.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/departments/departments_screen.dart';
import '../screens/employees/employee_details_screen.dart';
import '../screens/employees/employee_form_screen.dart';
import '../screens/employees/employee_list_screen.dart';
import '../screens/leave/apply_leave_screen.dart';
import '../screens/leave/leave_details_screen.dart';
import '../screens/leave/leave_requests_screen.dart';
import '../screens/leave/leave_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/tasks/task_details_screen.dart';
import '../screens/tasks/task_form_screen.dart';
import '../screens/tasks/task_list_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const dashboard = '/dashboard';
  static const employees = '/employees';
  static const employeeNew = '/employees/new';
  static const departments = '/departments';
  static const tasks = '/tasks';
  static const taskNew = '/tasks/new';
  static const attendance = '/attendance';
  static const attendanceReport = '/attendance/report';
  static const leave = '/leave';
  static const leaveApply = '/leave/apply';
  static const leaveRequests = '/leave/requests';
  static const notifications = '/notifications';
  static const announcements = '/announcements';
  static const announcementNew = '/announcements/new';

  static String employeeDetail(String id) => '/employees/$id';
  static String employeeEdit(String id) => '/employees/$id/edit';
  static String taskDetail(String id) => '/tasks/$id';
  static String taskEdit(String id) => '/tasks/$id/edit';
  static String leaveDetail(String id) => '/leave/$id';
  static String announcementDetail(String id) => '/announcements/$id';
  static String announcementEdit(String id) => '/announcements/$id/edit';
  static String resetPasswordFor(String email) =>
      Uri(path: resetPassword, queryParameters: email.isEmpty ? null : {'email': email}).toString();

  /// Reachable without signing in.
  static const _public = {login, register, forgotPassword, resetPassword};

  /// Route prefix -> roles allowed. Mirrors the backend's RBAC so users never land on
  /// a screen whose API calls would all return 403.
  static const _roleGuards = <String, Set<UserRole>>{
    employees: {UserRole.admin, UserRole.manager},
    departments: {UserRole.admin},
  };

  /// Exact screens inside an otherwise open section. `/tasks`, `/attendance` and `/leave` are
  /// for everyone, but only staff create/edit tasks, see the team report or review leave.
  static final _patternGuards = <RegExp, Set<UserRole>>{
    RegExp(r'^/attendance/report$'): {UserRole.admin, UserRole.manager},
    RegExp(r'^/leave/requests$'): {UserRole.admin, UserRole.manager},
    RegExp(r'^/announcements/new$'): {UserRole.admin, UserRole.manager},
    RegExp(r'^/announcements/[^/]+/edit$'): {UserRole.admin, UserRole.manager},
    RegExp(r'^/tasks/new$'): {UserRole.admin, UserRole.manager},
    RegExp(r'^/tasks/[^/]+/edit$'): {UserRole.admin, UserRole.manager},
  };

  static bool canAccess(User user, String location) {
    for (final entry in _patternGuards.entries) {
      if (entry.key.hasMatch(location)) return entry.value.contains(user.role);
    }
    for (final entry in _roleGuards.entries) {
      if (location == entry.key || location.startsWith('${entry.key}/')) {
        return entry.value.contains(user.role);
      }
    }
    return true;
  }
}

/// The router is created once. Instead of rebuilding it on auth changes (which would
/// reset navigation), auth state is mirrored into a [ValueNotifier] that GoRouter
/// listens to; every change re-runs [redirect].
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  ref.listen(authControllerProvider, (_, next) => authState.value = next, fireImmediately: true);
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authState,
    redirect: (context, state) {
      final auth = authState.value;
      final location = state.matchedLocation;

      // Still checking the stored token, or the server was unreachable.
      if (auth.isLoading || auth.hasError) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final user = auth.value;
      final onPublic = AppRoutes._public.contains(location);

      if (user == null) return onPublic ? null : AppRoutes.login;
      if (onPublic || location == AppRoutes.splash) return AppRoutes.dashboard;
      if (!AppRoutes.canAccess(user, location)) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(initialEmail: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: AppRoutes.employees,
        builder: (context, state) => const EmployeeListScreen(),
        routes: [
          // 'new' must come before ':id' so it isn't treated as an id.
          GoRoute(path: 'new', builder: (context, state) => const EmployeeFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => EmployeeDetailsScreen(employeeId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => EmployeeFormScreen(employeeId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: AppRoutes.departments, builder: (context, state) => const DepartmentsScreen()),
      GoRoute(
        path: AppRoutes.attendance,
        builder: (context, state) => const AttendanceScreen(),
        routes: [GoRoute(path: 'report', builder: (context, state) => const AttendanceReportScreen())],
      ),
      GoRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: AppRoutes.announcements,
        builder: (context, state) => const AnnouncementListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const AnnouncementFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => AnnouncementDetailsScreen(announcementId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => AnnouncementFormScreen(announcementId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.leave,
        builder: (context, state) => const LeaveScreen(),
        routes: [
          // Fixed paths must come before ':id' so they aren't treated as ids.
          GoRoute(path: 'apply', builder: (context, state) => const ApplyLeaveScreen()),
          GoRoute(path: 'requests', builder: (context, state) => const LeaveRequestsScreen()),
          GoRoute(path: ':id', builder: (context, state) => LeaveDetailsScreen(leaveId: state.pathParameters['id']!)),
        ],
      ),
      GoRoute(
        path: AppRoutes.tasks,
        builder: (context, state) => const TaskListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const TaskFormScreen()),
          GoRoute(
            path: ':id',
            builder: (context, state) => TaskDetailsScreen(taskId: state.pathParameters['id']!),
            routes: [
              GoRoute(path: 'edit', builder: (context, state) => TaskFormScreen(taskId: state.pathParameters['id'])),
            ],
          ),
        ],
      ),
    ],
  );
});
