import 'package:flutter/material.dart' show DateUtils;

import '../core/utils/api_dates.dart';
import 'paginated.dart';
import 'person_ref.dart';

enum AttendanceStatus {
  present('present', 'Present'),
  late('late', 'Late'),
  halfDay('half_day', 'Half day'),
  absent('absent', 'Absent'),
  leave('leave', 'Leave');

  const AttendanceStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AttendanceStatus fromString(String? value) =>
      AttendanceStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => AttendanceStatus.present);
}

/// One person's attendance for one work day.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    this.user,
    this.checkIn,
    this.checkOut,
    this.workingMinutes = 0,
    this.status = AttendanceStatus.present,
  });

  final String id;

  /// The work day (calendar date in the company's time zone).
  final DateTime date;
  final PersonRef? user; // populated in lists; absent on check-in/out responses
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int workingMinutes;
  final AttendanceStatus status;

  bool get isCheckedIn => checkIn != null && checkOut == null;
  bool get isComplete => checkIn != null && checkOut != null;

  /// Checked in on an earlier day and never checked out.
  bool missedCheckOut([DateTime? now]) => isCheckedIn && date.isBefore(DateUtils.dateOnly(now ?? DateTime.now()));

  /// Time worked so far: the server's total once checked out, otherwise counted live.
  Duration worked([DateTime? now]) {
    if (isComplete) return Duration(minutes: workingMinutes);
    if (checkIn == null) return Duration.zero;
    final elapsed = (now ?? DateTime.now()).difference(checkIn!);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: (json['id'] ?? json['_id']) as String,
        date: ApiDates.parseDate(json['date'])!,
        user: PersonRef.fromJson(json['user']),
        checkIn: ApiDates.parseMoment(json['checkIn']),
        checkOut: ApiDates.parseMoment(json['checkOut']),
        workingMinutes: (json['workingMinutes'] as num?)?.toInt() ?? 0,
        status: AttendanceStatus.fromString(json['status'] as String?),
      );
}

/// Company rules, sent by the backend so the app never hard-codes them.
class AttendanceRules {
  const AttendanceRules({this.timeZone = '', this.workStart = '09:30', this.halfDayHours = 4});

  final String timeZone;
  final String workStart;
  final num halfDayHours;

  factory AttendanceRules.fromJson(Map<String, dynamic> json) => AttendanceRules(
        timeZone: json['timeZone'] as String? ?? '',
        workStart: json['workStart'] as String? ?? '09:30',
        halfDayHours: json['halfDayHours'] as num? ?? 4,
      );
}

/// GET /attendance/today
class AttendanceToday {
  const AttendanceToday({required this.date, this.record, this.rules = const AttendanceRules()});

  final DateTime date;
  final AttendanceRecord? record; // null until the user checks in
  final AttendanceRules rules;

  bool get canCheckIn => record == null;
  bool get canCheckOut => record?.isCheckedIn ?? false;

  factory AttendanceToday.fromJson(Map<String, dynamic> data) => AttendanceToday(
        date: ApiDates.parseDate(data['date'])!,
        record: data['attendance'] == null ? null : AttendanceRecord.fromJson(data['attendance'] as Map<String, dynamic>),
        rules: data['rules'] is Map ? AttendanceRules.fromJson(Map<String, dynamic>.from(data['rules'] as Map)) : const AttendanceRules(),
      );
}

/// Day counts per status and total time worked over the whole filtered range.
class AttendanceSummary {
  const AttendanceSummary({this.present = 0, this.late = 0, this.halfDay = 0, this.leave = 0, this.totalMinutes = 0});

  final int present;
  final int late;
  final int halfDay;
  final int leave;
  final int totalMinutes;

  int get daysWorked => present + late + halfDay;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AttendanceSummary(
      present: n('present'),
      late: n('late'),
      halfDay: n('half_day'),
      leave: n('leave'),
      totalMinutes: n('totalMinutes'),
    );
  }
}

/// GET /attendance: one page of records plus the summary.
class AttendanceHistory {
  const AttendanceHistory({required this.page, required this.summary});

  final Paginated<AttendanceRecord> page;
  final AttendanceSummary summary;

  factory AttendanceHistory.fromJson(Map<String, dynamic> data) => AttendanceHistory(
        page: Paginated.fromJson(data, AttendanceRecord.fromJson),
        summary: data['summary'] is Map
            ? AttendanceSummary.fromJson(Map<String, dynamic>.from(data['summary'] as Map))
            : const AttendanceSummary(),
      );
}
