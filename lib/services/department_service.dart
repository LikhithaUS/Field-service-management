import '../core/constants/api_constants.dart';
import '../models/department.dart';
import 'api_service.dart';

class DepartmentService {
  DepartmentService(this._api);

  final ApiService _api;

  Future<List<Department>> list() async {
    final body = await _api.get(ApiConstants.departments);
    final items = (body['data'] as Map<String, dynamic>)['items'] as List;
    return items.map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Department> create({required String name, String description = ''}) async {
    final body = await _api.post(ApiConstants.departments, data: {'name': name.trim(), 'description': description.trim()});
    return _unwrap(body);
  }

  Future<Department> update(String id, {required String name, String description = ''}) async {
    final body = await _api.put(
      '${ApiConstants.departments}/$id',
      data: {'name': name.trim(), 'description': description.trim()},
    );
    return _unwrap(body);
  }

  Future<void> delete(String id) => _api.delete('${ApiConstants.departments}/$id');

  Department _unwrap(Map<String, dynamic> body) =>
      Department.fromJson((body['data'] as Map<String, dynamic>)['department'] as Map<String, dynamic>);
}
