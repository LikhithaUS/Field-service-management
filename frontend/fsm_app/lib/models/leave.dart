import 'package:flutter/material.dart' show DateUtils;

import '../core/utils/api_dates.dart';
import 'person_ref.dart';
import 'user.dart';

enum LeaveType {
  casual('Casual leave'),
  sick('Sick leave'),
  annual('Annual leave'),
  other('Other');

  const LeaveType(this.label);

  final String label;

  String get apiValue => name;

  static LeaveType fromString(String? value) =>
      LeaveType.values.firstWhere((t) => t.name == value, orElse: () => LeaveType.other);
}

enum LeaveStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const LeaveStatus(this.label);

  final String label;

  String get apiValue => name;

  static LeaveStatus fromString(String? value) =>
      LeaveStatus.values.firstWhere((s) => s.name == value, orElse: () => LeaveStatus.pending);
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    this.user,
    this.status = LeaveStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote = '',
    this.createdAt,
  });

  final String id;
  final PersonRef? user; // who is taking leave
  final LeaveType leaveType;
  final DateTime startDate; // calendar dates, inclusive
  final DateTime endDate;
  final int days; // working days, counted by the backend
  final String reason;
  final LeaveStatus status;
  final PersonRef? reviewedBy;
  final DateTime? reviewedAt;
  final String reviewNote;
  final DateTime? createdAt;

  bool get isSingleDay => startDate == endDate;
  bool isOwnedBy(User user) => this.user?.id == user.id;

  /// Same rule as the backend: pending, or approved and not started yet.
  bool canBeCancelled([DateTime? now]) =>
      status == LeaveStatus.pending ||
      (status == LeaveStatus.approved && startDate.isAfter(DateUtils.dateOnly(now ?? DateTime.now())));

  /// Mon–Fri days in the range, the same count the backend stores in `days`.
  /// Used to preview the count on the apply form before submitting.
  static int workingDaysBetween(DateTime start, DateTime end) {
    var count = 0;
    for (var d = DateUtils.dateOnly(start); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: (json['id'] ?? json['_id']) as String,
        user: PersonRef.fromJson(json['user']),
        leaveType: LeaveType.fromString(json['leaveType'] as String?),
        startDate: ApiDates.parseDate(json['startDate'])!,
        endDate: ApiDates.parseDate(json['endDate'])!,
        days: (json['days'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        status: LeaveStatus.fromString(json['status'] as String?),
        reviewedBy: PersonRef.fromJson(json['reviewedBy']),
        reviewedAt: ApiDates.parseMoment(json['reviewedAt']),
        reviewNote: json['reviewNote'] as String? ?? '',
        createdAt: ApiDates.parseMoment(json['createdAt']),
      );
}
