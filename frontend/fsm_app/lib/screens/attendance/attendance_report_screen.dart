import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../models/attendance.dart';
import '../../models/attendance_query.dart';
import '../../models/person_ref.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/person_picker_dialog.dart';
import '../../widgets/state_views.dart';
import 'attendance_widgets.dart';

/// Admin/manager view of everyone's attendance for a day or date range.
class AttendanceReportScreen extends ConsumerWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(attendanceReportQueryProvider);
    final result = ref.watch(attendanceReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team attendance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              _Filters(query: query),
              SizedBox(height: 3, child: result.isLoading && result.hasValue ? const LinearProgressIndicator() : null),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) => _Report(history: value, query: query),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(attendanceReportProvider)),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.query});

  final AttendanceQuery query;

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(start: query.from, end: query.to),
    );
    if (picked != null) {
      ref.read(attendanceReportQueryProvider.notifier).setRange(DateUtils.dateOnly(picked.start), DateUtils.dateOnly(picked.end));
    }
  }

  Future<void> _pickPerson(BuildContext context, WidgetRef ref) async {
    final viewer = ref.read(authControllerProvider).value;
    if (viewer == null) return;
    final picked = await showDialog<PersonRef>(
      context: context,
      builder: (_) => PersonPickerDialog(viewer: viewer, title: 'Show attendance for', selfLabel: 'Me'),
    );
    if (picked != null) ref.read(attendanceReportQueryProvider.notifier).setPerson(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(attendanceReportQueryProvider.notifier);
    final rangeLabel = query.isSingleDay ? Formatters.date(query.from) : '${Formatters.date(query.from)} – ${Formatters.date(query.to)}';
    final isDefault = query == AttendanceQuery.today();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickRange(context, ref),
            icon: const Icon(Icons.date_range),
            label: Text(rangeLabel),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<AttendanceStatus?>(
              key: ValueKey('status:${query.status}'),
              initialValue: query.status,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Status', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: [
                const DropdownMenuItem(value: null, child: Text('All statuses')),
                for (final s in AttendanceStatus.values.where((s) => s != AttendanceStatus.absent))
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: notifier.setStatus,
            ),
          ),
          InputChip(
            avatar: const Icon(Icons.person_outline, size: 18),
            label: Text(query.person == null ? 'Everyone' : query.person!.name),
            onPressed: () => _pickPerson(context, ref),
            onDeleted: query.person == null ? null : () => notifier.setPerson(null),
            deleteButtonTooltipMessage: 'Show everyone',
          ),
          if (!isDefault)
            TextButton.icon(onPressed: notifier.reset, icon: const Icon(Icons.restart_alt), label: const Text('Reset')),
        ],
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.history, required this.query});

  final AttendanceHistory history;
  final AttendanceQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = history.page;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(attendanceReportProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AttendanceSummaryBar(summary: history.summary),
          const SizedBox(height: 6),
          Text("People who didn't check in don't appear here (counted as absent).", style: muted),
          const SizedBox(height: 12),
          if (page.items.isEmpty)
            const EmptyView(icon: Icons.event_busy_outlined, title: 'No attendance records for this selection')
          else ...[
            for (final r in page.items) ...[
              AttendanceRecordTile(record: r, showPerson: true, showDate: !query.isSingleDay),
              const SizedBox(height: 8),
            ],
            PaginationBar(page: page, onPageChanged: ref.read(attendanceReportQueryProvider.notifier).setPage),
          ],
        ],
      ),
    );
  }
}
