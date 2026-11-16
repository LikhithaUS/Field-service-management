import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/attendance.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/state_views.dart';
import 'attendance_widgets.dart';

/// Everyone's own attendance: today's check-in/out card and this month's history.
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const SizedBox.shrink();
    final today = ref.watch(attendanceTodayProvider);
    final history = ref.watch(myAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          if (!viewer.isEmployee)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.attendanceReport),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Team report'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshAttendance(ref);
          await ref.read(attendanceTodayProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    switch (today) {
                      AsyncValue(:final value?) => _TodayCard(today: value),
                      AsyncValue(:final error?) => SizedBox(
                          height: 260,
                          child: ErrorView(error: error, onRetry: () => ref.invalidate(attendanceTodayProvider)),
                        ),
                      _ => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
                    },
                    const SizedBox(height: 24),
                    Text('This month', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ..._history(context, ref, history),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _history(BuildContext context, WidgetRef ref, AsyncValue<AttendanceHistory> history) {
    return switch (history) {
      AsyncValue(:final value?) => [
          AttendanceSummaryBar(summary: value.summary),
          const SizedBox(height: 12),
          if (value.page.items.isEmpty)
            const EmptyView(icon: Icons.event_busy_outlined, title: 'No attendance this month yet')
          else ...[
            for (final r in value.page.items) ...[AttendanceRecordTile(record: r), const SizedBox(height: 8)],
            PaginationBar(page: value.page, onPageChanged: ref.read(myAttendanceQueryProvider.notifier).setPage),
          ],
        ],
      AsyncValue(:final error?) => [ErrorView(error: error, onRetry: () => ref.invalidate(myAttendanceProvider))],
      _ => [const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))],
    };
  }
}

/// Live clock + check-in/out button. Ticks every second so "Worked" counts up while checked in.
class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard({required this.today});

  final AttendanceToday today;

  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _checkIn() => _run(() => ref.read(attendanceServiceProvider).checkIn(), (r) {
        return r.status == AttendanceStatus.late
            ? 'Checked in at ${Formatters.time(r.checkIn)} (late)'
            : 'Checked in at ${Formatters.time(r.checkIn)}';
      });

  Future<void> _checkOut() async {
    final ok = await confirmDialog(
      context,
      title: 'Check out now?',
      message: 'You can only check in once per day, so this ends your work day.',
      confirmLabel: 'Check out',
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(attendanceServiceProvider).checkOut(),
      (r) => 'Checked out. You worked ${Formatters.duration(r.worked())} today.',
    );
  }

  Future<void> _run(Future<AttendanceRecord> Function() action, String Function(AttendanceRecord) message) async {
    setState(() => _busy = true);
    try {
      final record = await action();
      refreshAttendance(ref);
      if (mounted) showSnack(context, message(record));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final record = today.record;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final clock = '${Formatters.time(_now)}:${_now.second.toString().padLeft(2, '0')}';

    final Widget action;
    if (today.canCheckIn) {
      action = FilledButton.icon(
        onPressed: _busy ? null : _checkIn,
        icon: const Icon(Icons.login),
        label: const Text('Check in'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      );
    } else if (today.canCheckOut) {
      action = FilledButton.tonalIcon(
        onPressed: _busy ? null : _checkOut,
        icon: const Icon(Icons.logout),
        label: const Text('Check out'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      );
    } else {
      action = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, color: scheme.primary),
          const SizedBox(width: 8),
          const Text("You're done for today"),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(Formatters.dayDate(today.date), style: textTheme.titleMedium)),
                if (record != null) AttendanceStatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              clock,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TimeCell(label: 'Check in', value: Formatters.time(record?.checkIn)),
                _TimeCell(label: 'Check out', value: Formatters.time(record?.checkOut)),
                _TimeCell(label: 'Worked', value: record == null ? '—' : Formatters.duration(record.worked(_now))),
              ],
            ),
            const SizedBox(height: 20),
            action,
            const SizedBox(height: 12),
            Text(
              'Work starts at ${today.rules.workStart} · under ${today.rules.halfDayHours} hours counts as a half day',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
