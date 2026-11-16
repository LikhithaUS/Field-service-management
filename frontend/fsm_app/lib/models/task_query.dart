import 'task.dart';

/// Search, filter and paging state for the task list.
class TaskQuery {
  const TaskQuery({
    this.search = '',
    this.status,
    this.priority,
    this.mine = false,
    this.overdue = false,
    this.page = 1,
    this.limit = 10,
  });

  final String search;
  final TaskStatus? status;
  final TaskPriority? priority;

  /// Staff only: show just the tasks assigned to me. (Employees always get only theirs.)
  final bool mine;
  final bool overdue;
  final int page;
  final int limit;

  bool get hasFilters => search.isNotEmpty || status != null || priority != null || mine || overdue;

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (status != null) 'status': status!.apiValue,
        if (priority != null) 'priority': priority!.apiValue,
        if (mine) 'mine': 'true',
        if (overdue) 'overdue': 'true',
      };

  static const Object _unset = Object();

  /// Nullable filters use a sentinel so `copyWith(status: null)` clears the filter
  /// while omitting `status` keeps the current value.
  TaskQuery copyWith({
    String? search,
    Object? status = _unset,
    Object? priority = _unset,
    bool? mine,
    bool? overdue,
    int? page,
  }) {
    return TaskQuery(
      search: search ?? this.search,
      status: identical(status, _unset) ? this.status : status as TaskStatus?,
      priority: identical(priority, _unset) ? this.priority : priority as TaskPriority?,
      mine: mine ?? this.mine,
      overdue: overdue ?? this.overdue,
      page: page ?? this.page,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskQuery &&
      other.search == search &&
      other.status == status &&
      other.priority == priority &&
      other.mine == mine &&
      other.overdue == overdue &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(search, status, priority, mine, overdue, page, limit);
}
