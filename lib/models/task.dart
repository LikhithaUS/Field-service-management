import 'package:flutter/material.dart' show DateUtils;

import 'user.dart';

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

/// The small slice of a user that the backend populates on tasks and comments.
class TaskPerson {
  const TaskPerson({required this.id, required this.name, this.email = '', this.role = UserRole.employee, this.employeeId});

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? employeeId;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// A populated reference is an object; if the account was deleted it can be null.
  static TaskPerson? fromJson(Object? json) {
    if (json is! Map) return null;
    return TaskPerson(
      id: (json['id'] ?? json['_id']) as String,
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      employeeId: json['employeeId'] as String?,
    );
  }
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
  final TaskPerson? assignedTo;
  final TaskPerson? assignedBy;
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
        assignedTo: TaskPerson.fromJson(json['assignedTo']),
        assignedBy: TaskPerson.fromJson(json['assignedBy']),
        priority: TaskPriority.fromString(json['priority'] as String?),
        status: TaskStatus.fromString(json['status'] as String?),
        dueDate: parseApiDate(json['dueDate']),
        completedAt: _parseMoment(json['completedAt']),
        createdAt: _parseMoment(json['createdAt']),
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      );

  /// Date-only values arrive as `2026-12-01T00:00:00.000Z`. Converting that to local time
  /// would shift it to the previous day west of UTC, so keep the UTC calendar date instead.
  static DateTime? parseApiDate(Object? value) {
    if (value is! String) return null;
    final utc = DateTime.tryParse(value)?.toUtc();
    return utc == null ? null : DateTime(utc.year, utc.month, utc.day);
  }

  /// The inverse of [parseApiDate]: a local calendar date -> midnight UTC ISO string.
  static String toApiDate(DateTime date) => DateTime.utc(date.year, date.month, date.day).toIso8601String();

  static DateTime? _parseMoment(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

class TaskComment {
  const TaskComment({required this.id, required this.message, this.user, this.createdAt});

  final String id;
  final String message;
  final TaskPerson? user;
  final DateTime? createdAt;

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
        id: (json['id'] ?? json['_id']) as String,
        message: json['message'] as String,
        user: TaskPerson.fromJson(json['user']),
        createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String)?.toLocal() : null,
      );
}
