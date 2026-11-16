import '../core/utils/api_dates.dart';
import 'attendance.dart';
import 'person_ref.dart';

/// Date range, filters and page for an attendance list.
class AttendanceQuery {
  const AttendanceQuery({required this.from, required this.to, this.status, this.person, this.page = 1, this.limit = 10});

  /// The current calendar month up to today ("My attendance").
  factory AttendanceQuery.thisMonth([DateTime? now]) {
    final today = now ?? DateTime.now();
    return AttendanceQuery(from: DateTime(today.year, today.month, 1), to: DateTime(today.year, today.month, today.day));
  }

  /// Just today (the team report's default).
  factory AttendanceQuery.today([DateTime? now]) {
    final t = now ?? DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    return AttendanceQuery(from: day, to: day);
  }

  final DateTime from;
  final DateTime to;
  final AttendanceStatus? status;

  /// Staff only: one person's records. Ignored by the backend for employees.
  final PersonRef? person;
  final int page;
  final int limit;

  bool get isSingleDay => from == to;

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        'from': ApiDates.toDay(from),
        'to': ApiDates.toDay(to),
        if (status != null) 'status': status!.apiValue,
        if (person != null) 'user': person!.id,
      };

  static const Object _unset = Object();

  AttendanceQuery copyWith({DateTime? from, DateTime? to, Object? status = _unset, Object? person = _unset, int? page}) {
    return AttendanceQuery(
      from: from ?? this.from,
      to: to ?? this.to,
      status: identical(status, _unset) ? this.status : status as AttendanceStatus?,
      person: identical(person, _unset) ? this.person : person as PersonRef?,
      page: page ?? this.page,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AttendanceQuery &&
      other.from == from &&
      other.to == to &&
      other.status == status &&
      other.person?.id == person?.id &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(from, to, status, person?.id, page, limit);
}
