import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paginated.dart';
import '../models/task.dart';
import '../models/task_query.dart';
import 'service_providers.dart';

/// Current search/filter/page state. Kept alive so filters survive leaving and
/// returning to the list.
final taskQueryProvider = NotifierProvider<TaskQueryController, TaskQuery>(TaskQueryController.new);

class TaskQueryController extends Notifier<TaskQuery> {
  @override
  TaskQuery build() => const TaskQuery();

  // Changing any filter jumps back to page 1.
  void setSearch(String value) => state = state.copyWith(search: value.trim(), page: 1);
  void setStatus(TaskStatus? status) => state = state.copyWith(status: status, page: 1);
  void setPriority(TaskPriority? priority) => state = state.copyWith(priority: priority, page: 1);
  void setMine(bool value) => state = state.copyWith(mine: value, page: 1);
  void setOverdue(bool value) => state = state.copyWith(overdue: value, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void clear() => state = const TaskQuery();
}

/// The current page of tasks; re-fetches automatically whenever the query changes.
final taskListProvider = FutureProvider.autoDispose<Paginated<Task>>((ref) {
  final query = ref.watch(taskQueryProvider);
  return ref.watch(taskServiceProvider).list(query);
});

final taskDetailProvider = FutureProvider.autoDispose.family<Task, String>((ref, id) {
  return ref.watch(taskServiceProvider).get(id);
});

final taskCommentsProvider = FutureProvider.autoDispose.family<List<TaskComment>, String>((ref, taskId) {
  return ref.watch(taskServiceProvider).comments(taskId);
});

/// Call after creating/updating/deleting so the list and details show fresh data.
void refreshTaskData(WidgetRef ref, {String? taskId}) {
  ref.invalidate(taskListProvider);
  if (taskId != null) ref.invalidate(taskDetailProvider(taskId));
}
