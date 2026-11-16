import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/leave.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';
import 'leave_widgets.dart';

/// Permission rules mirrored from the backend so the UI only offers allowed actions.
class LeavePermissions {
  LeavePermissions(this.viewer, this.leave);

  final User viewer;
  final LeaveRequest leave;

  bool get isOwner => leave.isOwnedBy(viewer);

  /// Staff, not their own request, and managers only review employees.
  bool get canReview =>
      leave.status == LeaveStatus.pending &&
      !isOwner &&
      (viewer.isAdmin || (viewer.isManager && leave.user?.role == UserRole.employee));

  bool get canCancel => isOwner && leave.canBeCancelled();
}

class LeaveDetailsScreen extends ConsumerWidget {
  const LeaveDetailsScreen({super.key, required this.leaveId});

  final String leaveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    final result = ref.watch(leaveDetailProvider(leaveId));

    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: switch (result) {
        AsyncValue(:final value?) when viewer != null => _Details(leave: value, perms: LeavePermissions(viewer, value)),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(leaveDetailProvider(leaveId))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.leave, required this.perms});

  final LeaveRequest leave;
  final LeavePermissions perms;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const gap = SizedBox(height: 16);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(leave.leaveType.label, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  LeaveStatusBadge(status: leave.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${leaveRange(leave)} · ${leaveDays(leave.days)}', style: textTheme.titleMedium),
              gap,
              _Actions(leave: leave, perms: perms),
              gap,
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (!perms.isOwner) _InfoRow(icon: Icons.person_outline, label: 'Requested by', value: leave.user?.name ?? '—'),
                    _InfoRow(icon: Icons.notes, label: 'Reason', value: leave.reason),
                    _InfoRow(icon: Icons.schedule_outlined, label: 'Requested on', value: Formatters.dateTime(leave.createdAt)),
                    if (leave.reviewedBy != null) ...[
                      _InfoRow(
                        icon: Icons.how_to_reg_outlined,
                        label: leave.status == LeaveStatus.rejected ? 'Rejected by' : 'Approved by',
                        value: '${leave.reviewedBy!.name} · ${Formatters.dateTime(leave.reviewedAt)}',
                      ),
                      if (leave.reviewNote.isNotEmpty)
                        _InfoRow(icon: Icons.comment_outlined, label: 'Reviewer note', value: leave.reviewNote),
                    ],
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

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.leave, required this.perms});

  final LeaveRequest leave;
  final LeavePermissions perms;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Future<void> _run(Future<LeaveRequest> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      refreshLeaveData(ref, leaveId: widget.leave.id);
      if (mounted) showSnack(context, done);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review({required bool approve}) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(approve: approve, name: widget.leave.user?.name ?? 'this person'),
    );
    if (note == null || !mounted) return; // dialog cancelled
    final service = ref.read(leaveServiceProvider);
    await _run(
      () => approve ? service.approve(widget.leave.id, note: note) : service.reject(widget.leave.id, note: note),
      approve ? 'Leave approved' : 'Leave rejected',
    );
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this request?',
      message: widget.leave.status == LeaveStatus.approved
          ? 'Your approved leave will be withdrawn and removed from attendance.'
          : 'Your request will be withdrawn.',
      confirmLabel: 'Cancel request',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() => ref.read(leaveServiceProvider).cancel(widget.leave.id), 'Request cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final perms = widget.perms;
    final scheme = Theme.of(context).colorScheme;
    final buttons = <Widget>[
      if (perms.canReview) ...[
        FilledButton.icon(
          onPressed: _busy ? null : () => _review(approve: true),
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          onPressed: _busy ? null : () => _review(approve: false),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      ],
      if (perms.canCancel)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.undo),
          label: const Text('Cancel request'),
        ),
    ];

    if (buttons.isEmpty) {
      // Explain why a pending request can't be reviewed here.
      if (widget.leave.status == LeaveStatus.pending && perms.isOwner) {
        return Text('Waiting for approval.', style: TextStyle(color: scheme.onSurfaceVariant));
      }
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      ...buttons,
      if (_busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ]);
  }
}

/// Asks for an optional note. Returns the note ('' if none), or null if cancelled.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve, required this.name});

  final bool approve;
  final String name;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.approve ? 'Approve leave?' : 'Reject leave?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.name} will be notified by email.'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: widget.approve ? 'Note (optional)' : 'Reason for rejecting (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          style: widget.approve ? null : FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.approve ? 'Approve' : 'Reject'),
        ),
      ],
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
