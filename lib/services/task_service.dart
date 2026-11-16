import '../core/constants/api_constants.dart';
import '../models/paginated.dart';
import '../models/task.dart';
import '../models/task_query.dart';
import 'api_service.dart';

class TaskService {
  TaskService(this._api);

  final ApiService _api;

  Future<Paginated<Task>> list(TaskQuery query) async {
    final body = await _api.get(ApiConstants.tasks, query: query.toQueryParameters());
    return Paginated.fromJson(body['data'] as Map<String, dynamic>, Task.fromJson);
  }

  Future<Task> get(String id) async => _unwrap(await _api.get('${ApiConstants.tasks}/$id'));

  Future<Task> create(Map<String, dynamic> data) async => _unwrap(await _api.post(ApiConstants.tasks, data: data));

  Future<Task> update(String id, Map<String, dynamic> data) async =>
      _unwrap(await _api.put('${ApiConstants.tasks}/$id', data: data));

  /// Shortcut used by the status buttons on the details screen.
  Future<Task> updateStatus(String id, TaskStatus status) => update(id, {'status': status.apiValue});

  Future<void> delete(String id) => _api.delete('${ApiConstants.tasks}/$id');

  Future<List<TaskComment>> comments(String taskId) async {
    final body = await _api.get('${ApiConstants.tasks}/$taskId/comments');
    final items = (body['data'] as Map<String, dynamic>)['items'] as List;
    return items.map((e) => TaskComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskComment> addComment(String taskId, String message) async {
    final body = await _api.post('${ApiConstants.tasks}/$taskId/comments', data: {'message': message});
    return TaskComment.fromJson((body['data'] as Map<String, dynamic>)['comment'] as Map<String, dynamic>);
  }

  Task _unwrap(Map<String, dynamic> body) =>
      Task.fromJson((body['data'] as Map<String, dynamic>)['task'] as Map<String, dynamic>);
}
