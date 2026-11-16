import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/task_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';

/// Permission rules mirrored from the backend so the UI only offers allowed actions.
/// (The backend still enforces them; this just avoids showing buttons that would fail.)
class TaskPermissions {
  TaskPermissions(this.viewer, this.task);

  final User viewer;
  final Task task;

  bool get isStaff => viewer.isAdmin || viewer.isManager;
  bool get isAssignee => task.isAssignedTo(viewer);
  bool get canEdit => isStaff;
  bool get canDelete => isStaff;
  bool get canComment => isStaff || isAssignee;

  /// Assignees can't change a cancelled task, and only staff can cancel one.
  bool get canChangeStatus => isStaff || (isAssignee && task.status != TaskStatus.cancelled);
  bool get canCancel => isStaff && task.status.isOpen;
}

class TaskDetailsScreen extends ConsumerWidget {
  const TaskDetailsScreen({super.key, required this.taskId});

  final String taskId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${task.taskNumber}?',
      message: 'This permanently removes "${task.title}" and its comments.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(taskServiceProvider).delete(task.id);
      refreshTaskData(ref);
      if (!context.mounted) return;
      showSnack(context, '${task.taskNumber} was deleted');
      context.go(AppRoutes.tasks);
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    final result = ref.watch(taskDetailProvider(taskId));
    final task = result.value;
    final perms = (viewer != null && task != null) ? TaskPermissions(viewer, task) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          if (perms?.canEdit ?? false)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.taskEdit(taskId)),
            ),
          if (perms?.canDelete ?? false)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, task!),
            ),
        ],
      ),
      body: switch (result) {
        AsyncValue(:final value?) when perms != null => _Details(task: value, perms: perms),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(taskDetailProvider(taskId))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.task, required this.perms});

  final Task task;
  final TaskPermissions perms;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final overdue = task.isOverdue();
    const gap = SizedBox(height: 16);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(task.taskNumber, style: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              SelectableText(task.title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [TaskStatusBadge(status: task.status), PriorityBadge(priority: task.priority)],
              ),
              gap,
              _StatusActions(task: task, perms: perms),
              gap,
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.person_outline, label: 'Assigned to', value: task.assignedTo?.name ?? '—'),
                    _InfoRow(icon: Icons.supervisor_account_outlined, label: 'Assigned by', value: task.assignedBy?.name ?? '—'),
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: 'Due date',
                      value: task.dueDate == null ? 'No due date' : Formatters.date(task.dueDate) + (overdue ? ' (overdue)' : ''),
                      valueColor: overdue ? scheme.error : null,
                    ),
                    if (task.location.isNotEmpty)
                      _InfoRow(icon: Icons.place_outlined, label: 'Location', value: task.location),
                    _InfoRow(icon: Icons.schedule_outlined, label: 'Created', value: Formatters.dateTime(task.createdAt)),
                    if (task.completedAt != null)
                      _InfoRow(icon: Icons.check_circle_outline, label: 'Completed', value: Formatters.dateTime(task.completedAt)),
                  ],
                ),
              ),
              if (task.description.isNotEmpty) ...[
                gap,
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SelectableText(task.description),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _CommentsSection(taskId: task.id, canComment: perms.canComment),
            ],
          ),
        ),
      ),
    );
  }
}

/// The buttons offered depend on the current status: start → complete → (reopen).
class _StatusActions extends ConsumerStatefulWidget {
  const _StatusActions({required this.task, required this.perms});

  final Task task;
  final TaskPermissions perms;

  @override
  ConsumerState<_StatusActions> createState() => _StatusActionsState();
}

class _StatusActionsState extends ConsumerState<_StatusActions> {
  bool _busy = false;

  Future<void> _setStatus(TaskStatus status, String doneMessage) async {
    if (status == TaskStatus.cancelled) {
      final ok = await confirmDialog(
        context,
        title: 'Cancel this task?',
        message: 'The assignee will no longer be able to work on it. You can reopen it later.',
        confirmLabel: 'Cancel task',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(taskServiceProvider).updateStatus(widget.task.id, status);
      refreshTaskData(ref, taskId: widget.task.id);
      if (mounted) showSnack(context, doneMessage);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final perms = widget.perms;
    final scheme = Theme.of(context).colorScheme;

    if (!perms.canChangeStatus) {
      if (task.status != TaskStatus.cancelled) return const SizedBox.shrink();
      return Text('This task was cancelled.', style: TextStyle(color: scheme.onSurfaceVariant));
    }

    final buttons = <Widget>[
      if (task.status == TaskStatus.pending)
        FilledButton.icon(
          onPressed: _busy ? null : () => _setStatus(TaskStatus.inProgress, 'Task started'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start task'),
        ),
      if (task.status.isOpen)
        FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _setStatus(TaskStatus.completed, 'Task completed'),
          icon: const Icon(Icons.check),
          label: const Text('Mark completed'),
        ),
      if (task.status == TaskStatus.completed)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _setStatus(TaskStatus.inProgress, 'Task reopened'),
          icon: const Icon(Icons.replay),
          label: const Text('Reopen'),
        ),
      if (task.status == TaskStatus.cancelled) // only staff get here
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _setStatus(TaskStatus.pending, 'Task reopened'),
          icon: const Icon(Icons.replay),
          label: const Text('Reopen'),
        ),
      if (perms.canCancel)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: _busy ? null : () => _setStatus(TaskStatus.cancelled, 'Task cancelled'),
          icon: const Icon(Icons.block),
          label: const Text('Cancel task'),
        ),
    ];

    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      ...buttons,
      if (_busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ]);
  }
}

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({required this.taskId, required this.canComment});

  final String taskId;
  final bool canComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(taskCommentsProvider(taskId));
    final count = comments.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(count == null ? 'Comments' : 'Comments ($count)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        switch (comments) {
          AsyncValue(:final value?) when value.isEmpty => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No comments yet.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          AsyncValue(:final value?) => Column(children: [for (final c in value) _CommentTile(comment: c)]),
          AsyncValue(:final error?) => Row(
              children: [
                Expanded(child: Text(error is ApiException ? error.message : 'Could not load comments')),
                TextButton(onPressed: () => ref.invalidate(taskCommentsProvider(taskId)), child: const Text('Retry')),
              ],
            ),
          _ => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        },
        if (canComment) ...[const SizedBox(height: 8), _CommentComposer(taskId: taskId)],
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(initials: comment.user?.initials ?? '?', radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(comment.user?.name ?? 'Deleted user', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        Formatters.dateTime(comment.createdAt),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(comment.message),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(taskServiceProvider).addComment(widget.taskId, message);
      _controller.clear();
      ref.invalidate(taskCommentsProvider(widget.taskId));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 5,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Write a comment…',
        counterText: '',
        suffixIcon: _sending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(tooltip: 'Send comment', icon: const Icon(Icons.send), onPressed: _send),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      subtitle: SelectableText(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: valueColor)),
    );
  }
}
