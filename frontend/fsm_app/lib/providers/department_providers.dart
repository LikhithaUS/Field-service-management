import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/department.dart';
import 'service_providers.dart';

/// All departments (with employee counts). Used by the Departments screen and by
/// the department dropdowns/filters in the Employees module.
final departmentsProvider = AsyncNotifierProvider<DepartmentsController, List<Department>>(DepartmentsController.new);

class DepartmentsController extends AsyncNotifier<List<Department>> {
  @override
  Future<List<Department>> build() => ref.read(departmentServiceProvider).list();

  // Mutations throw ApiException so dialogs can show the message (e.g. duplicate name).
  Future<void> create({required String name, String description = ''}) async {
    await ref.read(departmentServiceProvider).create(name: name, description: description);
    await _reload();
  }

  Future<void> edit(String id, {required String name, String description = ''}) async {
    await ref.read(departmentServiceProvider).update(id, name: name, description: description);
    await _reload();
  }

  Future<void> remove(String id) async {
    await ref.read(departmentServiceProvider).delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncData(await ref.read(departmentServiceProvider).list());
  }
}
