import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/employee.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/state_views.dart';

/// Create (employeeId == null) or edit an employee.
class EmployeeFormScreen extends ConsumerWidget {
  const EmployeeFormScreen({super.key, this.employeeId});

  final String? employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEdit = employeeId != null;
    final Widget body;

    if (!isEdit) {
      body = const _EmployeeForm();
    } else {
      final result = ref.watch(employeeDetailProvider(employeeId!));
      body = switch (result) {
        AsyncValue(:final value?) => _EmployeeForm(initial: value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(employeeDetailProvider(employeeId!))),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit employee' : 'Add employee')),
      body: body,
    );
  }
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({this.initial});

  final Employee? initial;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _email = TextEditingController(text: widget.initial?.email);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _designation = TextEditingController(text: widget.initial?.designation);
  late String? _departmentId = widget.initial?.department?.id;
  late UserRole _role = widget.initial?.role ?? UserRole.employee;
  late EmployeeStatus _status = widget.initial?.status ?? EmployeeStatus.active;
  late DateTime _joiningDate = widget.initial?.joiningDate ?? DateUtils.dateOnly(DateTime.now());

  bool _saving = false;
  ApiException? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Map<String, dynamic> _payload(User viewer) => {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'designation': _designation.text.trim(),
        'department': _departmentId,
        'joiningDate': DateTime.utc(_joiningDate.year, _joiningDate.month, _joiningDate.day).toIso8601String(),
        // Only admins may set roles; managers always create/edit plain employees.
        if (viewer.isAdmin) 'role': _role.name,
        if (_isEdit) 'status': _status.name,
      };

  Future<void> _submit(User viewer) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final service = ref.read(employeeServiceProvider);
    try {
      if (_isEdit) {
        final updated = await service.update(widget.initial!.id, _payload(viewer));
        refreshEmployeeData(ref, employeeId: updated.id);
        if (!mounted) return;
        showSnack(context, 'Changes saved');
        context.go(AppRoutes.employeeDetail(updated.id));
      } else {
        final result = await service.create(_payload(viewer));
        refreshEmployeeData(ref);
        if (!mounted) return;
        showSnack(
          context,
          result.accountCreated
              ? 'Employee created. A setup code was emailed to ${result.employee.email}.'
              : 'Employee created and linked to their existing account.',
        );
        context.go(AppRoutes.employeeDetail(result.employee.id));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const SizedBox.shrink();

    final departments = ref.watch(departmentsProvider);
    final isSelf = _isEdit && viewer.employeeId == widget.initial!.employeeId;
    const gap = SizedBox(height: 16);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null && _error!.fieldErrors.isEmpty) ...[ErrorBanner(message: _error!.message), gap],
                if (!_isEdit) ...[
                  Text(
                    'A login account is created with this email, and a setup code is emailed so the employee can choose their own password.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  gap,
                ],
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v, field: 'Name'),
                  decoration: InputDecoration(
                    labelText: 'Full name *',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _error?.fieldErrors['name'],
                  ),
                ),
                gap,
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _error?.fieldErrors['email'],
                  ),
                ),
                gap,
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    errorText: _error?.fieldErrors['phone'],
                  ),
                ),
                gap,
                TextFormField(
                  controller: _designation,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Designation (job title)',
                    prefixIcon: const Icon(Icons.work_outline),
                    errorText: _error?.fieldErrors['designation'],
                  ),
                ),
                gap,
                DropdownButtonFormField<String?>(
                  initialValue: _departmentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: const Icon(Icons.apartment_outlined),
                    helperText: departments.hasError ? 'Could not load departments' : null,
                    errorText: _error?.fieldErrors['department'],
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No department')),
                    for (final d in departments.value ?? const []) DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                gap,
                if (viewer.isAdmin)
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      helperText: isSelf ? 'You cannot change your own role' : null,
                    ),
                    items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
                    onChanged: isSelf ? null : (v) => setState(() => _role = v ?? _role),
                  )
                else
                  const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      helperText: 'Only admins can assign other roles',
                    ),
                    child: Text('Employee'),
                  ),
                gap,
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Joining date', prefixIcon: Icon(Icons.event_outlined)),
                    child: Text(Formatters.date(_joiningDate)),
                  ),
                ),
                if (_isEdit) ...[
                  gap,
                  DropdownButtonFormField<EmployeeStatus>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      prefixIcon: const Icon(Icons.toggle_on_outlined),
                      helperText: isSelf
                          ? 'You cannot deactivate your own account'
                          : 'Inactive employees cannot sign in and are signed out immediately',
                    ),
                    items: [for (final s in EmployeeStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                    onChanged: isSelf ? null : (v) => setState(() => _status = v ?? _status),
                  ),
                ],
                const SizedBox(height: 28),
                LoadingButton(
                  label: _isEdit ? 'Save changes' : 'Create employee',
                  loading: _saving,
                  onPressed: () => _submit(viewer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
