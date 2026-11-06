import 'package:flutter/material.dart';

import '../models/employee.dart';
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
