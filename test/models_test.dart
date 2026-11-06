import 'package:flutter_test/flutter_test.dart';

import 'package:fsm_app/core/utils/formatters.dart';
import 'package:fsm_app/core/utils/validators.dart';
import 'package:fsm_app/models/department.dart';
import 'package:fsm_app/models/employee.dart';
import 'package:fsm_app/models/employee_query.dart';
import 'package:fsm_app/models/paginated.dart';
import 'package:fsm_app/models/user.dart';

void main() {
  group('Employee.fromJson', () {
    test('parses a populated department', () {
      final e = Employee.fromJson({
        'id': 'abc',
        'employeeId': 'EMP-0007',
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
        'phone': '+91 98765 43210',
        'designation': 'Technician',
        'department': {'id': 'd1', 'name': 'Operations'},
        'role': 'manager',
        'status': 'inactive',
        'joiningDate': '2026-03-01T00:00:00.000Z',
      });
      expect(e.department!.name, 'Operations');
      expect(e.role, UserRole.manager);
      expect(e.status, EmployeeStatus.inactive);
      expect(e.isActive, isFalse);
      expect(e.initials, 'PS');
      expect(e.joiningDate, isNotNull);
    });

    test('handles missing optional fields and no department', () {
      final e = Employee.fromJson({'id': 'x', 'employeeId': 'EMP-0001', 'name': 'Cher', 'email': 'c@x.com', 'department': null});
      expect(e.department, isNull);
      expect(e.phone, '');
      expect(e.status, EmployeeStatus.active);
      expect(e.initials, 'C');
    });
  });

  test('Department.fromJson accepts a bare id', () {
    expect(Department.fromJson('d9').id, 'd9');
    expect(Department.fromJson({'id': 'd1', 'name': 'IT', 'employeeCount': 3}).employeeCount, 3);
  });

  test('Paginated computes the visible range', () {
    final p = Paginated<int>.fromJson(
      {
        'items': [
          {'v': 1},
        ],
        'pagination': {'page': 2, 'limit': 10, 'total': 15, 'totalPages': 2},
      },
      (m) => m['v'] as int,
    );
    expect(p.from, 11);
    expect(p.to, 15);
    expect(p.hasPrevious, isTrue);
    expect(p.hasNext, isFalse);
  });

  group('EmployeeQuery', () {
    test('only sends active filters', () {
      expect(const EmployeeQuery().toQueryParameters(), {'page': 1, 'limit': 10});
      final q = const EmployeeQuery().copyWith(search: 'anil', departmentId: 'd1', role: UserRole.manager, status: EmployeeStatus.active);
      expect(q.toQueryParameters(), {
        'page': 1,
        'limit': 10,
        'search': 'anil',
        'department': 'd1',
        'role': 'manager',
        'status': 'active',
      });
    });

    test('copyWith can clear a filter with null and keep it when omitted', () {
      final q = const EmployeeQuery().copyWith(role: UserRole.admin, departmentId: 'd1');
      expect(q.copyWith(page: 3).role, UserRole.admin);
      expect(q.copyWith(role: null).role, isNull);
      expect(q.copyWith(role: null).departmentId, 'd1');
      expect(q.hasFilters, isTrue);
      expect(const EmployeeQuery().hasFilters, isFalse);
    });
  });

  test('Validators.phone is optional but validated', () {
    expect(Validators.phone(''), isNull);
    expect(Validators.phone('+91 98765 43210'), isNull);
    expect(Validators.phone('abc'), isNotNull);
  });

  test('Formatters.date', () {
    expect(Formatters.date(DateTime(2026, 11, 6)), '06 Nov 2026');
    expect(Formatters.date(null), '—');
  });
}
