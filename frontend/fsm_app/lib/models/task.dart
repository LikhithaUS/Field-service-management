import 'package:flutter/material.dart' show DateUtils;

import '../core/utils/api_dates.dart';
import 'person_ref.dart';
import 'user.dart';

export 'person_ref.dart';

/// Backend values are snake_case (`in_progress`), so each enum keeps its API value.
enum TaskStatus {
  pending('pending', 'Pending'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const TaskStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get isOpen => this == pending || this == inProgress;

  static TaskStatus fromString(String? value) =>
      TaskStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => TaskStatus.pending);
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const TaskPriority(this.label);

  final String label;

  String get apiValue => name;

  static TaskPriority fromString(String? value) =>
      TaskPriority.values.firstWhere((p) => p.name == value, orElse: () => TaskPriority.medium);
}

class Task {
  const Task({
    required this.id,
    required this.taskNumber,
    required this.title,
    this.description = '',
    this.location = '',
    this.assignedTo,
    this.assignedBy,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.completedAt,
    this.createdAt,
    this.commentCount = 0,
  });

  final String id;
  final String taskNumber; // human-friendly, e.g. TSK-0001
  final String title;
  final String description;
  final String location;
  final PersonRef? assignedTo;
  final PersonRef? assignedBy;
  final TaskPriority priority;
  final TaskStatus status;

  /// A calendar date (no time). The backend stores midnight UTC of the chosen day.
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final int commentCount;

  /// Still open and the due date is before today (same rule as the backend).
  bool isOverdue([DateTime? now]) {
    if (dueDate == null || !status.isOpen) return false;
    return dueDate!.isBefore(DateUtils.dateOnly(now ?? DateTime.now()));
  }

  bool isAssignedTo(User user) => assignedTo?.id == user.id;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: (json['id'] ?? json['_id']) as String,
        taskNumber: json['taskNumber'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        assignedTo: PersonRef.fromJson(json['assignedTo']),
        assignedBy: PersonRef.fromJson(json['assignedBy']),
        priority: TaskPriority.fromString(json['priority'] as String?),
        status: TaskStatus.fromString(json['status'] as String?),
        dueDate: parseApiDate(json['dueDate']),
        completedAt: _parseMoment(json['completedAt']),
        createdAt: _parseMoment(json['createdAt']),
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      );

  static DateTime? parseApiDate(Object? value) => ApiDates.parseDate(value);
  static String toApiDate(DateTime date) => ApiDates.toIso(date);

  static DateTime? _parseMoment(Object? value) => ApiDates.parseMoment(value);
}

class TaskComment {
  const TaskComment({required this.id, required this.message, this.user, this.createdAt});

  final String id;
  final String message;
  final PersonRef? user;
  final DateTime? createdAt;

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
        id: (json['id'] ?? json['_id']) as String,
        message: json['message'] as String,
        user: PersonRef.fromJson(json['user']),
        createdAt: ApiDates.parseMoment(json['createdAt']),
      );
}
