import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leave.dart';
import '../models/leave_query.dart';
import '../models/paginated.dart';
import 'attendance_providers.dart';
import 'service_providers.dart';

class LeaveQueryController extends Notifier<LeaveQuery> {
  LeaveQueryController(this._initial);

  final LeaveQuery _initial;

  @override
  LeaveQuery build() => _initial;

  // Changing a filter jumps back to page 1.
  void setStatus(LeaveStatus? status) => state = state.copyWith(status: status, page: 1);
  void setType(LeaveType? type) => state = state.copyWith(leaveType: type, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
}

/// "My leave": the signed-in user's own requests.
final myLeaveQueryProvider = NotifierProvider.autoDispose<LeaveQueryController, LeaveQuery>(
  () => LeaveQueryController(const LeaveQuery(mine: true)),
);

final myLeavesProvider = FutureProvider.autoDispose<Paginated<LeaveRequest>>((ref) {
  return ref.watch(leaveServiceProvider).list(ref.watch(myLeaveQueryProvider));
});

/// Staff review queue: everyone's requests, pending first by default.
final leaveRequestsQueryProvider = NotifierProvider.autoDispose<LeaveQueryController, LeaveQuery>(
  () => LeaveQueryController(const LeaveQuery(status: LeaveStatus.pending)),
);

final leaveRequestsProvider = FutureProvider.autoDispose<Paginated<LeaveRequest>>((ref) {
  return ref.watch(leaveServiceProvider).list(ref.watch(leaveRequestsQueryProvider));
});

final leaveDetailProvider = FutureProvider.autoDispose.family<LeaveRequest, String>((ref, id) {
  return ref.watch(leaveServiceProvider).get(id);
});

/// Call after applying/reviewing/cancelling. Approved leave also changes attendance.
void refreshLeaveData(WidgetRef ref, {String? leaveId}) {
  ref.invalidate(myLeavesProvider);
  ref.invalidate(leaveRequestsProvider);
  if (leaveId != null) ref.invalidate(leaveDetailProvider(leaveId));
  refreshAttendance(ref);
}
