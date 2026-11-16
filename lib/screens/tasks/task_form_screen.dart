import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/employee.dart';
import '../../models/employee_query.dart';
import '../../models/paginated.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/task_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/state_views.dart';

/// Create (taskId == null) or edit a task. Admins and managers only (guarded by the router).
class TaskFormScreen extends ConsumerWidget {
  const TaskFormScreen({super.key, this.taskId});

  final String? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEdit = taskId != null;
    final Widget body;

    if (!isEdit) {
      body = const _TaskForm();
    } else {
      final result = ref.watch(taskDetailProvider(taskId!));
      body = switch (result) {
        AsyncValue(:final value?) => _TaskForm(initial: value),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(taskDetailProvider(taskId!))),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit task' : 'New task')),
      body: body,
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.initial});

  final Task? initial;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _location = TextEditingController(text: widget.initial?.location);
  late TaskPerson? _assignee = widget.initial?.assignedTo;
  late TaskPriority _priority = widget.initial?.priority ?? TaskPriority.medium;
  late TaskStatus _status = widget.initial?.status ?? TaskStatus.pending;
  late DateTime? _dueDate = widget.initial?.dueDate;

  bool _saving = false;
  ApiException? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      // Allow an existing past due date to stay selectable when editing.
      firstDate: (_dueDate != null && _dueDate!.isBefore(today)) ? _dueDate! : today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Map<String, dynamic> _payload() => {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'assignedTo': _assignee!.id,
        'priority': _priority.apiValue,
        'dueDate': _dueDate == null ? null : Task.toApiDate(_dueDate!),
        if (_isEdit) 'status': _status.apiValue,
      };

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final service = ref.read(taskServiceProvider);
    try {
      final saved = _isEdit ? await service.update(widget.initial!.id, _payload()) : await service.create(_payload());
      refreshTaskData(ref, taskId: saved.id);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Changes saved' : '${saved.taskNumber} assigned to ${saved.assignedTo?.name}');
      context.go(AppRoutes.taskDetail(saved.id));
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
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 150,
                  validator: (v) => Validators.required(v, field: 'Title'),
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    prefixIcon: const Icon(Icons.title),
                    errorText: _error?.fieldErrors['title'],
                  ),
                ),
                gap,
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes),
                    errorText: _error?.fieldErrors['description'],
                  ),
                ),
                gap,
                // FormField so "assignee is required" goes through the same validate() call.
                FormField<TaskPerson>(
                  initialValue: _assignee,
                  validator: (v) => v == null ? 'Choose who the task is assigned to' : null,
                  builder: (field) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDialog<TaskPerson>(
                        context: context,
                        builder: (_) => AssigneePickerDialog(viewer: viewer),
                      );
                      if (picked == null) return;
                      setState(() => _assignee = picked);
                      field.didChange(picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Assigned to *',
                        prefixIcon: const Icon(Icons.person_outline),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        errorText: field.errorText ?? _error?.fieldErrors['assignedTo'],
                      ),
                      isEmpty: _assignee == null,
                      child: _assignee == null ? null : Text(_assignee!.name),
                    ),
                  ),
                ),
                gap,
                DropdownButtonFormField<TaskPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority', prefixIcon: Icon(Icons.flag_outlined)),
                  items: [for (final p in TaskPriority.values) DropdownMenuItem(value: p, child: Text(p.label))],
                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                ),
                gap,
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due date',
                      prefixIcon: const Icon(Icons.event_outlined),
                      errorText: _error?.fieldErrors['dueDate'],
                      suffixIcon: _dueDate == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear due date',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _dueDate = null),
                            ),
                    ),
                    child: Text(_dueDate == null ? 'No due date' : Formatters.date(_dueDate)),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'Job site address',
                    prefixIcon: const Icon(Icons.place_outlined),
                    errorText: _error?.fieldErrors['location'],
                  ),
                ),
                if (_isEdit) ...[
                  gap,
                  DropdownButtonFormField<TaskStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.toggle_on_outlined)),
                    items: [for (final s in TaskStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ],
                const SizedBox(height: 28),
                LoadingButton(label: _isEdit ? 'Save changes' : 'Create task', loading: _saving, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable list of active employees with a login account, plus "Assign to me".
/// Returns the chosen person's *user* id, since tasks are assigned to accounts.
class AssigneePickerDialog extends ConsumerStatefulWidget {
  const AssigneePickerDialog({super.key, required this.viewer});

  final User viewer;

  @override
  ConsumerState<AssigneePickerDialog> createState() => _AssigneePickerDialogState();
}

class _AssigneePickerDialogState extends ConsumerState<AssigneePickerDialog> {
  late Future<Paginated<Employee>> _results = _load('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<Paginated<Employee>> _load(String search) => ref
      .read(employeeServiceProvider)
      .list(EmployeeQuery(search: search.trim(), status: EmployeeStatus.active, limit: 20));

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _results = _load(value)));
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.viewer;

    return AlertDialog(
      title: const Text('Assign to'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(hintText: 'Search employees…', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Assign to me'),
              subtitle: Text(me.name),
              onTap: () => Navigator.pop(
                context,
                TaskPerson(id: me.id, name: me.name, email: me.email, role: me.role, employeeId: me.employeeId),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<Paginated<Employee>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final e = snapshot.error;
                    return Center(child: Text(e is ApiException ? e.message : 'Could not load employees'));
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  // Employees without a linked account can't sign in, so they can't be assigned.
                  final people = snapshot.data!.items.where((e) => e.userId != null && e.userId != me.id).toList();
                  if (people.isEmpty) return const Center(child: Text('No matching employees'));

                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final e = people[i];
                      return ListTile(
                        leading: InitialsAvatar(initials: e.initials),
                        title: Text(e.name),
                        subtitle: Text(
                          [e.employeeId, if (e.designation.isNotEmpty) e.designation].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          TaskPerson(id: e.userId!, name: e.name, email: e.email, role: e.role, employeeId: e.employeeId),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
