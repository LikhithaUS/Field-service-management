import 'package:flutter_test/flutter_test.dart';

import 'package:fsm_app/core/utils/formatters.dart';
import 'package:fsm_app/core/utils/validators.dart';
import 'package:fsm_app/models/department.dart';
import 'package:fsm_app/models/employee.dart';
import 'package:fsm_app/models/employee_query.dart';
import 'package:fsm_app/models/paginated.dart';
import 'package:fsm_app/models/task.dart';
import 'package:fsm_app/models/task_query.dart';
import 'package:fsm_app/models/user.dart';

void main() {
  group('Task.fromJson', () {
    test('parses populated people, snake_case status and a date-only due date', () {
      final t = Task.fromJson({
        'id': 't1',
        'taskNumber': 'TSK-0001',
        'title': 'Install router',
        'assignedTo': {'id': 'u1', 'name': 'Priya Sharma', 'email': 'p@x.com', 'role': 'employee'},
        'assignedBy': {'id': 'u2', 'name': 'Maya', 'role': 'manager'},
        'priority': 'urgent',
        'status': 'in_progress',
        'dueDate': '2026-12-01T00:00:00.000Z',
        'completedAt': null,
        'createdAt': '2026-11-01T09:30:00.000Z',
        'commentCount': 3,
      });
      expect(t.status, TaskStatus.inProgress);
      expect(t.priority, TaskPriority.urgent);
      expect(t.assignedTo!.initials, 'PS');
      expect(t.assignedBy!.role, UserRole.manager);
      // The calendar date survives regardless of the device's time zone.
      expect(t.dueDate, DateTime(2026, 12, 1));
      expect(t.commentCount, 3);
      expect(t.description, '');
    });

    test('handles a deleted assignee and missing optional fields', () {
      final t = Task.fromJson({'id': 't2', 'taskNumber': 'TSK-0002', 'title': 'X', 'assignedTo': null});
      expect(t.assignedTo, isNull);
      expect(t.dueDate, isNull);
      expect(t.status, TaskStatus.pending);
      expect(t.priority, TaskPriority.medium);
    });

    test('date helpers round-trip', () {
      expect(Task.toApiDate(DateTime(2026, 3, 9)), '2026-03-09T00:00:00.000Z');
      expect(Task.parseApiDate(Task.toApiDate(DateTime(2026, 3, 9))), DateTime(2026, 3, 9));
    });
  });

  group('Task.isOverdue', () {
    final now = DateTime(2026, 11, 16, 15);
    Task due(DateTime? d, [TaskStatus s = TaskStatus.pending]) =>
        Task(id: 't', taskNumber: 'TSK-1', title: 'x', dueDate: d, status: s);

    test('only open tasks due before today are overdue', () {
      expect(due(DateTime(2026, 11, 15)).isOverdue(now), isTrue);
      expect(due(DateTime(2026, 11, 16)).isOverdue(now), isFalse); // due today
      expect(due(null).isOverdue(now), isFalse);
      expect(due(DateTime(2026, 11, 1), TaskStatus.completed).isOverdue(now), isFalse);
      expect(due(DateTime(2026, 11, 1), TaskStatus.cancelled).isOverdue(now), isFalse);
      expect(due(DateTime(2026, 11, 1), TaskStatus.inProgress).isOverdue(now), isTrue);
    });
  });

  group('TaskQuery', () {
    test('copyWith keeps or clears nullable filters', () {
      const q = TaskQuery(status: TaskStatus.completed, priority: TaskPriority.low, page: 3);
      expect(q.copyWith(page: 1).status, TaskStatus.completed);
      expect(q.copyWith(status: null).status, isNull);
      expect(q.copyWith(status: null).priority, TaskPriority.low);
      expect(q.hasFilters, isTrue);
      expect(const TaskQuery().hasFilters, isFalse);
      expect(const TaskQuery(mine: true) == const TaskQuery(mine: true), isTrue);
    });

    test('only sends set filters', () {
      expect(const TaskQuery().toQueryParameters(), {'page': 1, 'limit': 10});
      expect(
        const TaskQuery(search: 'ac', priority: TaskPriority.high, mine: true).toQueryParameters(),
        {'page': 1, 'limit': 10, 'search': 'ac', 'priority': 'high', 'mine': 'true'},
      );
    });
  });

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
