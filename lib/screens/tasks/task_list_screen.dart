import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/paginated.dart';
import '../../models/task.dart';
import '../../models/task_query.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/state_views.dart';

/// Staff see every task ("Tasks"); employees only see their own ("My tasks").
/// The backend enforces that, so the same screen and query work for both.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  late final TextEditingController _search = TextEditingController(text: ref.read(taskQueryProvider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Wait until the user pauses typing before hitting the API.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(taskQueryProvider.notifier).setSearch(value);
    });
  }

  void _clearFilters() {
    _search.clear();
    ref.read(taskQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const SizedBox.shrink();
    final isStaff = !viewer.isEmployee;
    final query = ref.watch(taskQueryProvider);
    final result = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isStaff ? 'Tasks' : 'My tasks')),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.taskNew),
              icon: const Icon(Icons.add_task),
              label: const Text('New task'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search title, task number, location…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              _Filters(query: query, viewer: viewer, onClear: _clearFilters),
              // Thin progress bar while a new page/filter loads over the previous results.
              SizedBox(height: 3, child: result.isLoading && result.hasValue ? const LinearProgressIndicator() : null),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) =>
                    _TaskList(page: value, hasFilters: query.hasFilters, isStaff: isStaff, onClear: _clearFilters),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(taskListProvider)),
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
  const _Filters({required this.query, required this.viewer, required this.onClear});

  final TaskQuery query;
  final User viewer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskQueryProvider.notifier);

    // `key` forces each dropdown to rebuild when its filter is cleared externally.
    Widget dropdown<T>({
      required String label,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return SizedBox(
        width: 170,
        child: DropdownButtonFormField<T?>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: items,
          onChanged: onChanged,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          dropdown<TaskStatus>(
            label: 'Status',
            value: query.status,
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses')),
              for (final s in TaskStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: notifier.setStatus,
          ),
          dropdown<TaskPriority>(
            label: 'Priority',
            value: query.priority,
            items: [
              const DropdownMenuItem(value: null, child: Text('All priorities')),
              for (final p in TaskPriority.values) DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: notifier.setPriority,
          ),
          FilterChip(
            label: const Text('Overdue'),
            avatar: query.overdue ? null : const Icon(Icons.warning_amber_rounded, size: 18),
            selected: query.overdue,
            onSelected: notifier.setOverdue,
          ),
          if (!viewer.isEmployee)
            FilterChip(
              label: const Text('Assigned to me'),
              avatar: query.mine ? null : const Icon(Icons.person_outline, size: 18),
              selected: query.mine,
              onSelected: notifier.setMine,
            ),
          if (query.hasFilters)
            TextButton.icon(onPressed: onClear, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.page, required this.hasFilters, required this.isStaff, required this.onClear});

  final Paginated<Task> page;
  final bool hasFilters;
  final bool isStaff;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.items.isEmpty) {
      if (hasFilters) {
        return EmptyView(
          icon: Icons.search_off,
          title: 'No tasks match your filters',
          action: OutlinedButton(onPressed: onClear, child: const Text('Clear filters')),
        );
      }
      return EmptyView(
        icon: Icons.task_alt_outlined,
        title: 'No tasks yet',
        message: isStaff ? 'Tap "New task" to assign the first one.' : 'Tasks assigned to you will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(taskListProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), // room for the FAB
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == page.items.length) {
            return PaginationBar(page: page, onPageChanged: ref.read(taskQueryProvider.notifier).setPage);
          }
          return _TaskTile(task: page.items[index], showAssignee: isStaff);
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.showAssignee});

  final Task task;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = task.isOverdue();
    final muted = TextStyle(color: scheme.onSurfaceVariant);

    final details = [
      task.taskNumber,
      if (showAssignee) task.assignedTo?.name ?? 'Unassigned',
      if (task.location.isNotEmpty) task.location,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: task.status == TaskStatus.cancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text.rich(
          TextSpan(
            style: muted,
            children: [
              TextSpan(text: details),
              if (task.dueDate != null) ...[
                const TextSpan(text: '\n'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.event_outlined, size: 14, color: overdue ? scheme.error : scheme.onSurfaceVariant),
                ),
                TextSpan(
                  text: overdue ? ' Overdue · due ${Formatters.date(task.dueDate)}' : ' Due ${Formatters.date(task.dueDate)}',
                  style: overdue ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600) : null,
                ),
              ],
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [TaskStatusBadge(status: task.status), PriorityBadge(priority: task.priority)],
        ),
        onTap: () => context.push(AppRoutes.taskDetail(task.id)),
      ),
    );
  }
}
