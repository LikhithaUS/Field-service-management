import '../core/constants/api_constants.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/paginated.dart';
import 'api_service.dart';

class EmployeeService {
  EmployeeService(this._api);

  final ApiService _api;

  Future<Paginated<Employee>> list(EmployeeQuery query) async {
    final body = await _api.get(ApiConstants.employees, query: query.toQueryParameters());
    return Paginated.fromJson(body['data'] as Map<String, dynamic>, Employee.fromJson);
  }

  Future<Employee> get(String id) async {
    final body = await _api.get('${ApiConstants.employees}/$id');
    return _unwrap(body);
  }

  /// `accountCreated` is true when a new login was created and a setup code emailed,
  /// false when an existing self-registered account was linked.
  Future<({Employee employee, bool accountCreated})> create(Map<String, dynamic> data) async {
    final body = await _api.post(ApiConstants.employees, data: data);
    return (
      employee: _unwrap(body),
      accountCreated: (body['data'] as Map<String, dynamic>)['accountCreated'] as bool? ?? false,
    );
  }

  Future<Employee> update(String id, Map<String, dynamic> data) async {
    final body = await _api.put('${ApiConstants.employees}/$id', data: data);
    return _unwrap(body);
  }

  Future<void> delete(String id) => _api.delete('${ApiConstants.employees}/$id');

  Employee _unwrap(Map<String, dynamic> body) =>
      Employee.fromJson((body['data'] as Map<String, dynamic>)['employee'] as Map<String, dynamic>);
}
