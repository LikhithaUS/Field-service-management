import 'leave.dart';

/// Filters and page for a leave list.
class LeaveQuery {
  const LeaveQuery({this.status, this.leaveType, this.mine = false, this.page = 1, this.limit = 10});

  final LeaveStatus? status;
  final LeaveType? leaveType;

  /// Only my own requests (staff otherwise see everyone's; employees always see only theirs).
  final bool mine;
  final int page;
  final int limit;

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status!.apiValue,
        if (leaveType != null) 'leaveType': leaveType!.apiValue,
        if (mine) 'mine': 'true',
      };

  static const Object _unset = Object();

  LeaveQuery copyWith({Object? status = _unset, Object? leaveType = _unset, int? page}) {
    return LeaveQuery(
      status: identical(status, _unset) ? this.status : status as LeaveStatus?,
      leaveType: identical(leaveType, _unset) ? this.leaveType : leaveType as LeaveType?,
      mine: mine,
      page: page ?? this.page,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LeaveQuery &&
      other.status == status &&
      other.leaveType == leaveType &&
      other.mine == mine &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(status, leaveType, mine, page, limit);
}
