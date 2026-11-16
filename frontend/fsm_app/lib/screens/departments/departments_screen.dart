import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/validators.dart';
import '../../models/department.dart';
import '../../providers/department_providers.dart';
import '../../providers/employee_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/state_views.dart';

/// Admin-only: list, create, rename and delete departments.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Department d) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${d.name}?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(departmentsProvider.notifier).remove(d.id);
      if (context.mounted) showSnack(context, '${d.name} deleted');
    } on ApiException catch (e) {
      // e.g. "Sales still has 3 employee(s). Reassign them before deleting."
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  void _viewEmployees(BuildContext context, WidgetRef ref, Department d) {
    ref.read(employeeQueryProvider.notifier)
      ..clear()
      ..setDepartment(d.id);
    context.push(AppRoutes.employees);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const DepartmentDialog()),
        icon: const Icon(Icons.add),
        label: const Text('Add department'),
      ),
      body: switch (result) {
        AsyncValue(:final value?) when value.isEmpty => const EmptyView(
            icon: Icons.apartment_outlined,
            title: 'No departments yet',
            message: 'Create departments like IT, HR or Operations.',
          ),
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () => ref.refresh(departmentsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: value.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = value[i];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                        leading: const Icon(Icons.apartment_outlined),
                        title: Text(d.name),
                        subtitle: Text(d.description.isEmpty ? 'No description' : d.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActionChip(
                              label: Text('${d.employeeCount} ${d.employeeCount == 1 ? 'employee' : 'employees'}'),
                              onPressed: () => _viewEmployees(context, ref, d),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'More',
                              onSelected: (action) => action == 'edit'
                                  ? showDialog<void>(context: context, builder: (_) => DepartmentDialog(department: d))
                                  : _delete(context, ref, d),
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(departmentsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Create (department == null) or edit dialog.
class DepartmentDialog extends ConsumerStatefulWidget {
  const DepartmentDialog({super.key, this.department});

  final Department? department;

  @override
  ConsumerState<DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends ConsumerState<DepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.department?.name);
  late final _description = TextEditingController(text: widget.department?.description);
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final notifier = ref.read(departmentsProvider.notifier);
    try {
      if (widget.department == null) {
        await notifier.create(name: _name.text, description: _description.text);
      } else {
        await notifier.edit(widget.department!.id, name: _name.text, description: _description.text);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.department != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit department' : 'New department'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null && _error!.fieldErrors.isEmpty) ...[
                ErrorBanner(message: _error!.statusCode == 409 ? 'A department with this name already exists' : _error!.message),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, field: 'Name'),
                decoration: InputDecoration(labelText: 'Name *', errorText: _error?.fieldErrors['name']),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(labelText: 'Description', errorText: _error?.fieldErrors['description']),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
