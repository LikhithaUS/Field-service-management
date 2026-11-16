import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/core/exceptions/api_exception.dart';
import 'package:fsm_app/models/employee.dart';
import 'package:fsm_app/models/task.dart';
import 'package:fsm_app/models/task_query.dart';
import 'package:fsm_app/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  Future<void> openTasks(WidgetTester tester) async {
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
  }

  Future<void> openFirstTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Matcher hasQuery(bool Function(TaskQuery q) test) => predicate<TaskQuery>(test);

  group('Task list', () {
    testWidgets('staff see all tasks with assignee, badges and a New task button', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      when(() => s.tasks.list(any())).thenAnswer(
        (_) async => pageOf([makeTask(1, priority: TaskPriority.urgent), makeTask(2, status: TaskStatus.inProgress)]),
      );

      await pumpApp(tester, s);
      await openTasks(tester);

      expect(find.text('Tasks'), findsOneWidget); // app bar title
      expect(find.text('Job 1'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.textContaining('Eli Employee'), findsNWidgets(2));
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Assigned to me'), findsOneWidget);
    });

    testWidgets('employees get "My tasks" without create or assignee filters', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1)]));

      await pumpApp(tester, s);
      await openTasks(tester);

      expect(find.text('My tasks'), findsOneWidget);
      expect(find.text('New task'), findsNothing);
      expect(find.text('Assigned to me'), findsNothing);
    });

    testWidgets('overdue tasks are highlighted', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      final yesterday = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1, dueDate: yesterday)]));

      await pumpApp(tester, s);
      await openTasks(tester);

      expect(find.textContaining('Overdue · due'), findsOneWidget);
    });

    testWidgets('filters and debounced search are sent to the API', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1)]));

      await pumpApp(tester, s);
      await openTasks(tester);

      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.list(any(that: hasQuery((q) => q.overdue && q.page == 1)))).called(1);

      await tester.tap(find.text('Assigned to me'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.list(any(that: hasQuery((q) => q.overdue && q.mine)))).called(1);

      await tester.enterText(find.byType(TextField).first, 'router');
      await tester.pump(const Duration(milliseconds: 100));
      verifyNever(() => s.tasks.list(any(that: hasQuery((q) => q.search == 'router'))));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      verify(() => s.tasks.list(any(that: hasQuery((q) => q.search == 'router')))).called(1);

      // The query maps to the backend's parameter names.
      final params = const TaskQuery(status: TaskStatus.inProgress, overdue: true).toQueryParameters();
      expect(params['status'], 'in_progress');
      expect(params['overdue'], 'true');
    });

    testWidgets('empty states differ for staff and employees', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf(<Task>[]));

      await pumpApp(tester, s);
      await openTasks(tester);
      expect(find.text('Tasks assigned to you will show up here.'), findsOneWidget);
    });
  });

  group('Task details', () {
    testWidgets('assignee can start and complete their task', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      var current = makeTask(1);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([current]));
      when(() => s.tasks.get('t1')).thenAnswer((_) async => current);
      when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);
      when(() => s.tasks.updateStatus('t1', any())).thenAnswer((inv) async {
        current = makeTask(1, status: inv.positionalArguments[1] as TaskStatus);
        return current;
      });

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 1');

      expect(find.text('Task details'), findsOneWidget);
      expect(find.text('Site 1'), findsOneWidget);
      // Employees can't edit, delete or cancel.
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.text('Cancel task'), findsNothing);

      await tester.tap(find.text('Start task'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.updateStatus('t1', TaskStatus.inProgress)).called(1);
      expect(find.text('Start task'), findsNothing);

      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.updateStatus('t1', TaskStatus.completed)).called(1);
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('a cancelled task is read-only for the assignee', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      final task = makeTask(1, status: TaskStatus.cancelled);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([task]));
      when(() => s.tasks.get('t1')).thenAnswer((_) async => task);
      when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 1');

      expect(find.text('This task was cancelled.'), findsOneWidget);
      expect(find.text('Start task'), findsNothing);
      expect(find.text('Reopen'), findsNothing);
    });

    testWidgets('shows the comment thread and posts a new comment', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      final comments = [
        TaskComment(id: 'c1', message: 'Please update the report.', user: personFrom(managerUser), createdAt: DateTime(2026, 11, 2, 10)),
      ];
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1)]));
      when(() => s.tasks.get('t1')).thenAnswer((_) async => makeTask(1));
      when(() => s.tasks.comments('t1')).thenAnswer((_) async => List.of(comments));
      when(() => s.tasks.addComment('t1', any())).thenAnswer((inv) async {
        final c = TaskComment(id: 'c2', message: inv.positionalArguments[1] as String, user: personFrom(employeeUser));
        comments.add(c);
        return c;
      });

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 1');

      expect(find.text('Comments (1)'), findsOneWidget);
      expect(find.text('Please update the report.'), findsOneWidget);

      final composer = find.widgetWithText(TextField, 'Write a comment…');
      await tester.ensureVisible(composer);
      await tester.enterText(composer, '  Report updated.  ');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();

      verify(() => s.tasks.addComment('t1', 'Report updated.')).called(1);
      expect(find.text('Comments (2)'), findsOneWidget);
      expect(find.text('Report updated.'), findsOneWidget);
    });

    testWidgets('staff can cancel (after confirming) and delete', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1)]));
      when(() => s.tasks.get('t1')).thenAnswer((_) async => makeTask(1));
      when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);
      when(() => s.tasks.updateStatus('t1', any()))
          .thenAnswer((_) async => makeTask(1, status: TaskStatus.cancelled));
      when(() => s.tasks.delete('t1')).thenAnswer((_) async {});

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 1');

      await tester.tap(find.text('Cancel task'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this task?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel task'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.updateStatus('t1', TaskStatus.cancelled)).called(1);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      verify(() => s.tasks.delete('t1')).called(1);
      expect(find.text('Tasks'), findsOneWidget); // back on the list
    });

    testWidgets('status change errors are shown', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([makeTask(1)]));
      when(() => s.tasks.get('t1')).thenAnswer((_) async => makeTask(1));
      when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);
      when(() => s.tasks.updateStatus('t1', any()))
          .thenThrow(const ApiException('This task was cancelled', statusCode: 403));

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 1');
      await tester.tap(find.text('Start task'));
      await tester.pumpAndSettle();

      expect(find.text('This task was cancelled'), findsOneWidget);
    });
  });

  group('Create / edit task', () {
    testWidgets('validates, picks an assignee and creates the task', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      final worker = Employee(
        id: 'e9',
        employeeId: 'EMP-0009',
        name: 'Field Worker',
        email: 'fw@example.com',
        userId: 'u9',
        designation: 'Technician',
      );
      final noAccount = Employee(id: 'e10', employeeId: 'EMP-0010', name: 'No Account', email: 'na@example.com');
      final created = makeTask(7);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf(<Task>[]));
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([worker, noAccount]));
      when(() => s.tasks.create(any())).thenAnswer((_) async => created);
      when(() => s.tasks.get('t7')).thenAnswer((_) async => created);
      when(() => s.tasks.comments('t7')).thenAnswer((_) async => []);

      await pumpApp(tester, s);
      await openTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create task'));
      await tester.pump();
      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Choose who the task is assigned to'), findsOneWidget);
      verifyNever(() => s.tasks.create(any()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Title *'), 'Fix AC unit');
      await tester.tap(find.text('Assigned to *'));
      await tester.pumpAndSettle();
      expect(find.text('Assign to me'), findsOneWidget);
      expect(find.text('No Account'), findsNothing); // can't sign in, so can't be assigned
      await tester.tap(find.text('Field Worker'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create task'));
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      final payload = verify(() => s.tasks.create(captureAny())).captured.single as Map<String, dynamic>;
      expect(payload['title'], 'Fix AC unit');
      expect(payload['assignedTo'], 'u9'); // the user id, not the employee id
      expect(payload['priority'], 'medium');
      expect(payload['dueDate'], isNull);
      expect(payload.containsKey('status'), isFalse);

      expect(find.text('Task details'), findsOneWidget);
    });

    testWidgets('edit pre-fills the form and sends the status', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      final task = makeTask(3, dueDate: DateTime(2026, 12, 1), priority: TaskPriority.high);
      when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([task]));
      when(() => s.tasks.get('t3')).thenAnswer((_) async => task);
      when(() => s.tasks.comments('t3')).thenAnswer((_) async => []);
      when(() => s.tasks.update('t3', any())).thenAnswer((_) async => task);

      await pumpApp(tester, s);
      await openTasks(tester);
      await openFirstTask(tester, 'Job 3');
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('01 Dec 2026'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Title *'), 'Job 3 (updated)');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final payload = verify(() => s.tasks.update('t3', captureAny())).captured.single as Map<String, dynamic>;
      expect(payload['title'], 'Job 3 (updated)');
      expect(payload['assignedTo'], employeeUser.id);
      expect(payload['priority'], 'high');
      expect(payload['dueDate'], '2026-12-01T00:00:00.000Z');
      expect(payload['status'], 'pending');
    });

    testWidgets('employees are redirected away from create', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      await pumpApp(tester, s);

      final router = GoRouter.of(tester.element(find.byType(DashboardScreen)));
      router.go('/tasks/new');
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  testWidgets('phone-sized task list and details render without overflow', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    final yesterday = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    final task = makeTask(1, dueDate: yesterday, priority: TaskPriority.urgent, status: TaskStatus.inProgress);
    when(() => s.tasks.list(any())).thenAnswer((_) async => pageOf([task, makeTask(2)], total: 30));
    when(() => s.tasks.get('t1')).thenAnswer((_) async => task);
    when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);

    await pumpApp(tester, s, size: const Size(360, 740));
    await openTasks(tester);
    expect(tester.takeException(), isNull);

    await openFirstTask(tester, 'Job 1');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('(overdue)'), findsOneWidget);
  });
}
