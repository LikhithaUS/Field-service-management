import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/leave.dart';
import '../../providers/leave_providers.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/state_views.dart';
import 'leave_widgets.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  LeaveType _type = LeaveType.casual;
  DateTimeRange? _range;
  String? _rangeError;
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  // Same rule as the backend: only sick leave may start in the past.
  DateTime get _firstAllowed {
    final today = DateUtils.dateOnly(DateTime.now());
    return _type == LeaveType.sick ? today.subtract(const Duration(days: 60)) : today;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstAllowed,
      lastDate: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Select leave dates',
    );
    if (picked != null) {
      setState(() {
        _range = DateTimeRange(start: DateUtils.dateOnly(picked.start), end: DateUtils.dateOnly(picked.end));
        _rangeError = null;
      });
    }
  }

  void _setType(LeaveType type) {
    setState(() {
      _type = type;
      // Switching away from sick leave can make a past start date invalid.
      if (_range != null && _range!.start.isBefore(_firstAllowed)) _range = null;
    });
  }

  String? _validateRange() {
    if (_range == null) return 'Choose your leave dates';
    if (LeaveRequest.workingDaysBetween(_range!.start, _range!.end) == 0) {
      return 'The selected dates contain no working days';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _rangeError = _validateRange();
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _rangeError != null) return;

    setState(() => _saving = true);
    try {
      final leave = await ref.read(leaveServiceProvider).apply(
            leaveType: _type,
            startDate: _range!.start,
            endDate: _range!.end,
            reason: _reason.text.trim(),
          );
      refreshLeaveData(ref);
      if (!mounted) return;
      showSnack(context, 'Leave request sent for approval');
      context.pushReplacement(AppRoutes.leaveDetail(leave.id));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = _range == null ? null : LeaveRequest.workingDaysBetween(_range!.start, _range!.end);
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for leave')),
      body: SingleChildScrollView(
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
                  DropdownButtonFormField<LeaveType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Leave type', prefixIcon: Icon(Icons.category_outlined)),
                    items: [for (final t in LeaveType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                    onChanged: (v) => _setType(v ?? _type),
                  ),
                  gap,
                  InkWell(
                    onTap: _pickRange,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Dates *',
                        prefixIcon: const Icon(Icons.date_range),
                        helperText: days == null ? null : leaveDays(days),
                        helperStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                        errorText: _rangeError ?? _error?.fieldErrors['startDate'] ?? _error?.fieldErrors['endDate'],
                      ),
                      isEmpty: _range == null,
                      child: _range == null
                          ? null
                          : Text(_range!.start == _range!.end
                              ? Formatters.dayDate(_range!.start)
                              : '${Formatters.date(_range!.start)} – ${Formatters.date(_range!.end)}'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _type == LeaveType.sick
                        ? 'Weekends are not counted. Sick leave can also be recorded for past days.'
                        : 'Weekends are not counted.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  gap,
                  TextFormField(
                    controller: _reason,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => Validators.required(v, field: 'Reason'),
                    decoration: InputDecoration(
                      labelText: 'Reason *',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.notes),
                      errorText: _error?.fieldErrors['reason'],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(label: 'Submit request', loading: _saving, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
