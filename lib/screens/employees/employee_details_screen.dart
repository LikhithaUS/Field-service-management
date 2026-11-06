import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/employee.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_providers.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';

/// Permission rules mirrored from the backend so the UI only offers allowed actions.
/// (The backend still enforces them; this just avoids showing buttons that would fail.)
class EmployeePermissions {
  EmployeePermissions(this.viewer, this.employee);

  final User viewer;
  final Employee employee;

  bool get isSelf => viewer.employeeId != null && viewer.employeeId == employee.employeeId;
  bool get canEdit => viewer.isAdmin || (viewer.isManager && employee.role == UserRole.employee);
  bool get canDelete => viewer.isAdmin && !isSelf;
}

class EmployeeDetailsScreen extends ConsumerWidget {
  const EmployeeDetailsScreen({super.key, required this.employeeId});

  final String employeeId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Employee employee) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${employee.name}?',
      message: 'This permanently removes the employee record and their login account.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(employeeServiceProvider).delete(employee.id);
      refreshEmployeeData(ref);
      if (!context.mounted) return;
      showSnack(context, '${employee.name} was deleted');
      context.go(AppRoutes.employees);
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    final result = ref.watch(employeeDetailProvider(employeeId));
    final employee = result.value;
    final perms = (viewer != null && employee != null) ? EmployeePermissions(viewer, employee) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee details'),
        actions: [
          if (perms?.canEdit ?? false)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.employeeEdit(employeeId)),
            ),
          if (perms?.canDelete ?? false)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, employee!),
            ),
        ],
      ),
      body: switch (result) {
        AsyncValue(:final value?) => _Details(employee: value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(employeeDetailProvider(employeeId))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: InitialsAvatar(initials: employee.initials, radius: 40)),
              const SizedBox(height: 12),
              Text(employee.name, textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (employee.designation.isNotEmpty)
                Text(employee.designation, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [RoleBadge(role: employee.role), StatusBadge(status: employee.status)],
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.badge_outlined, label: 'Employee ID', value: employee.employeeId),
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: employee.email),
                    _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: employee.phone.isEmpty ? '—' : employee.phone),
                    _InfoRow(icon: Icons.apartment_outlined, label: 'Department', value: employee.department?.name ?? '—'),
                    _InfoRow(icon: Icons.event_outlined, label: 'Joining date', value: Formatters.date(employee.joiningDate)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      subtitle: SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
