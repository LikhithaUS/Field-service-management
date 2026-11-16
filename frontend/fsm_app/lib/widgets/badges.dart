import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/leave.dart';
import '../models/task.dart';
import '../models/user.dart';

/// Circle with the person's initials (replaced by a photo once uploads exist).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.initials, this.radius = 20});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w600, fontSize: radius * 0.75)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final EmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return status == EmployeeStatus.active
        ? _Pill(label: status.label, background: scheme.tertiaryContainer, foreground: scheme.onTertiaryContainer)
        : _Pill(label: status.label, background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant);
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (role) {
      UserRole.admin => _Pill(label: role.label, background: scheme.errorContainer, foreground: scheme.onErrorContainer),
      UserRole.manager =>
        _Pill(label: role.label, background: scheme.secondaryContainer, foreground: scheme.onSecondaryContainer),
      UserRole.employee => _Pill(label: role.label, background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer),
    };
  }
}

class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      TaskStatus.pending =>
        _Pill(label: status.label, background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant),
      TaskStatus.inProgress =>
        _Pill(label: status.label, background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer),
      TaskStatus.completed =>
        _Pill(label: status.label, background: scheme.tertiaryContainer, foreground: scheme.onTertiaryContainer),
      TaskStatus.cancelled => _Pill(label: status.label, background: scheme.outlineVariant, foreground: scheme.onSurface),
    };
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (priority) {
      TaskPriority.low =>
        _Pill(label: priority.label, background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant),
      TaskPriority.medium =>
        _Pill(label: priority.label, background: scheme.secondaryContainer, foreground: scheme.onSecondaryContainer),
      TaskPriority.high => _Pill(label: priority.label, background: scheme.errorContainer, foreground: scheme.onErrorContainer),
      TaskPriority.urgent => _Pill(label: priority.label, background: scheme.error, foreground: scheme.onError),
    };
  }
}

class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      AttendanceStatus.present =>
        _Pill(label: status.label, background: scheme.tertiaryContainer, foreground: scheme.onTertiaryContainer),
      AttendanceStatus.late => _Pill(label: status.label, background: scheme.errorContainer, foreground: scheme.onErrorContainer),
      AttendanceStatus.halfDay =>
        _Pill(label: status.label, background: scheme.secondaryContainer, foreground: scheme.onSecondaryContainer),
      AttendanceStatus.absent => _Pill(label: status.label, background: scheme.error, foreground: scheme.onError),
      AttendanceStatus.leave =>
        _Pill(label: status.label, background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer),
    };
  }
}

class LeaveStatusBadge extends StatelessWidget {
  const LeaveStatusBadge({super.key, required this.status});

  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      LeaveStatus.pending =>
        _Pill(label: status.label, background: scheme.secondaryContainer, foreground: scheme.onSecondaryContainer),
      LeaveStatus.approved =>
        _Pill(label: status.label, background: scheme.tertiaryContainer, foreground: scheme.onTertiaryContainer),
      LeaveStatus.rejected => _Pill(label: status.label, background: scheme.errorContainer, foreground: scheme.onErrorContainer),
      LeaveStatus.cancelled =>
        _Pill(label: status.label, background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant),
    };
  }
}
