import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/attendance_query.dart';
import '../models/person_ref.dart';
import 'service_providers.dart';

/// The signed-in user's record for today (drives the Check in / Check out button).
final attendanceTodayProvider = FutureProvider.autoDispose<AttendanceToday>((ref) {
  return ref.watch(attendanceServiceProvider).today();
});

class AttendanceQueryController extends Notifier<AttendanceQuery> {
  AttendanceQueryController(this._initial);

  final AttendanceQuery Function() _initial;

  @override
  AttendanceQuery build() => _initial();

  // Changing any filter jumps back to page 1.
  void setRange(DateTime from, DateTime to) => state = state.copyWith(from: from, to: to, page: 1);
  void setStatus(AttendanceStatus? status) => state = state.copyWith(status: status, page: 1);
  void setPerson(PersonRef? person) => state = state.copyWith(person: person, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void reset() => state = _initial();
}

/// "My attendance" history: this month by default.
final myAttendanceQueryProvider = NotifierProvider.autoDispose<AttendanceQueryController, AttendanceQuery>(
  () => AttendanceQueryController(AttendanceQuery.thisMonth),
);

final myAttendanceProvider = FutureProvider.autoDispose<AttendanceHistory>((ref) {
  return ref.watch(attendanceServiceProvider).list(ref.watch(myAttendanceQueryProvider));
});

/// Staff team report: today by default.
final attendanceReportQueryProvider = NotifierProvider.autoDispose<AttendanceQueryController, AttendanceQuery>(
  () => AttendanceQueryController(AttendanceQuery.today),
);

final attendanceReportProvider = FutureProvider.autoDispose<AttendanceHistory>((ref) {
  return ref.watch(attendanceServiceProvider).list(ref.watch(attendanceReportQueryProvider));
});

/// Call after checking in/out so today's card and the history both update.
void refreshAttendance(WidgetRef ref) {
  ref.invalidate(attendanceTodayProvider);
  ref.invalidate(myAttendanceProvider);
  ref.invalidate(attendanceReportProvider);
}
