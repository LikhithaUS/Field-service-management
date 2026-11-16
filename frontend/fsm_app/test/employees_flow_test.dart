import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/core/exceptions/api_exception.dart';
import 'package:fsm_app/models/employee_query.dart';
import 'package:fsm_app/models/user.dart';
import 'package:fsm_app/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  Future<void> openEmployees(WidgetTester tester) async {
    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle();
  }

  group('Employee list', () {
    testWidgets('shows employees with pagination info', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([makeEmployee(1), makeEmployee(2)], total: 12, limit: 2));

      await pumpApp(tester, s);
      await openEmployees(tester);

      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Person 2'), findsOneWidget);
      expect(find.text('Showing 1–2 of 12'), findsOneWidget);
    });

    testWidgets('search is debounced and sent to the API', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([makeEmployee(1)]));

      await pumpApp(tester, s);
      await openEmployees(tester);

      await tester.enterText(find.byType(TextField).first, 'priya');
      await tester.pump(const Duration(milliseconds: 100));
      verifyNever(() => s.employees.list(any(that: _hasSearch('priya'))));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      verify(() => s.employees.list(any(that: _hasSearch('priya')))).called(1);
    });

    testWidgets('next page requests page 2', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.list(any())).thenAnswer((inv) async {
        final q = inv.positionalArguments.first as EmployeeQuery;
        return pageOf([makeEmployee(q.page)], page: q.page, total: 20);
      });

      await pumpApp(tester, s);
      await openEmployees(tester);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();

      expect(find.text('Person 2'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('empty results with filters offer to clear them', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([]));

      await pumpApp(tester, s);
      await openEmployees(tester);
      expect(find.text('No employees yet'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No employees match your filters'), findsOneWidget);
    });
  });

  group('Create employee', () {
    testWidgets('validates, submits and opens the new employee', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      final created = makeEmployee(5);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([]));
      when(() => s.employees.create(any())).thenAnswer((_) async => (employee: created, accountCreated: true));
      when(() => s.employees.get('e5')).thenAnswer((_) async => created);

      await pumpApp(tester, s);
      await openEmployees(tester);
      await tester.tap(find.text('Add employee'));
      await tester.pumpAndSettle();

      // Required fields are checked before calling the API.
      await tester.tap(find.text('Create employee'));
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      verifyNever(() => s.employees.create(any()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full name *'), 'Person 5');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email *'), 'person5@example.com');
      await tester.ensureVisible(find.text('Create employee'));
      await tester.tap(find.text('Create employee'));
      await tester.pumpAndSettle();

      final payload = verify(() => s.employees.create(captureAny())).captured.single as Map<String, dynamic>;
      expect(payload['name'], 'Person 5');
      expect(payload['email'], 'person5@example.com');
      expect(payload['role'], 'employee'); // admin form includes the role

      expect(find.text('Employee details'), findsOneWidget);
      expect(find.textContaining('setup code was emailed'), findsOneWidget);
    });

    testWidgets('managers cannot pick a role and do not send one', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([]));
      when(() => s.employees.create(any())).thenAnswer((_) async => (employee: makeEmployee(6), accountCreated: true));
      when(() => s.employees.get(any())).thenAnswer((_) async => makeEmployee(6));

      await pumpApp(tester, s);
      await openEmployees(tester);
      await tester.tap(find.text('Add employee'));
      await tester.pumpAndSettle();

      expect(find.text('Only admins can assign other roles'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full name *'), 'Person 6');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email *'), 'person6@example.com');
      await tester.ensureVisible(find.text('Create employee'));
      await tester.tap(find.text('Create employee'));
      await tester.pumpAndSettle();

      final payload = verify(() => s.employees.create(captureAny())).captured.single as Map<String, dynamic>;
      expect(payload.containsKey('role'), isFalse);
    });

    testWidgets('shows server field errors (duplicate email)', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([]));
      when(() => s.employees.create(any())).thenThrow(
        const ApiException('An employee with this email already exists', statusCode: 409),
      );

      await pumpApp(tester, s);
      await openEmployees(tester);
      await tester.tap(find.text('Add employee'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Full name *'), 'Dup');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email *'), 'dup@example.com');
      await tester.ensureVisible(find.text('Create employee'));
      await tester.tap(find.text('Create employee'));
      await tester.pumpAndSettle();

      expect(find.text('An employee with this email already exists'), findsOneWidget);
    });
  });

  group('Employee details permissions', () {
    Future<void> openDetails(WidgetTester tester, TestServices s, {UserRole targetRole = UserRole.employee}) async {
      final emp = makeEmployee(3, role: targetRole);
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([emp]));
      when(() => s.employees.get('e3')).thenAnswer((_) async => emp);
      await pumpApp(tester, s);
      await openEmployees(tester);
      await tester.tap(find.text('Person 3'));
      await tester.pumpAndSettle();
    }

    testWidgets('admin sees edit and delete', (tester) async {
      await openDetails(tester, TestServices(signedInAs: adminUser));
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('manager can edit employees but not delete', (tester) async {
      await openDetails(tester, TestServices(signedInAs: managerUser));
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('manager cannot edit another manager', (tester) async {
      await openDetails(tester, TestServices(signedInAs: managerUser), targetRole: UserRole.manager);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('admin deletes after confirming', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.employees.delete('e3')).thenAnswer((_) async {});
      await openDetails(tester, s);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => s.employees.delete('e3')).called(1);
      expect(find.text('Person 3 was deleted'), findsOneWidget);
    });
  });

  group('Role-based navigation', () {
    testWidgets('employees see neither tile and are redirected from /employees', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      await pumpApp(tester, s);

      expect(find.text('Employees'), findsNothing);
      expect(find.text('Departments'), findsNothing);

      GoRouter.of(tester.element(find.byType(DashboardScreen))).go('/employees');
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      verifyNever(() => s.employees.list(any()));
    });

    testWidgets('managers cannot open departments', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      await pumpApp(tester, s);
      expect(find.text('Departments'), findsNothing);

      GoRouter.of(tester.element(find.byType(DashboardScreen))).go('/departments');
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  testWidgets('phone-sized screens render without overflow', (tester) async {
    final s = TestServices(signedInAs: adminUser);
    final emp = makeEmployee(1, role: UserRole.manager);
    when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([emp, makeEmployee(2)], total: 25));
    when(() => s.employees.get('e1')).thenAnswer((_) async => emp);

    await pumpApp(tester, s, size: const Size(360, 740));
    await openEmployees(tester); // list + filters
    await tester.tap(find.text('Person 1'));
    await tester.pumpAndSettle(); // details
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle(); // form
    expect(find.text('Edit employee'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone-sized departments screen renders without overflow', (tester) async {
    await pumpApp(tester, TestServices(signedInAs: adminUser), size: const Size(360, 740));
    await tester.tap(find.text('Departments'));
    await tester.pumpAndSettle();
    expect(find.text('IT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone-sized reset password screen renders without overflow', (tester) async {
    await pumpApp(tester, TestServices(), size: const Size(360, 740));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already have a code'));
    await tester.pumpAndSettle();
    expect(find.text('Set a new password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Departments', () {
    testWidgets('lists departments with counts and creates one', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.departments.create(name: 'Sales', description: '')).thenAnswer((_) async => itDept);

      await pumpApp(tester, s);
      await tester.tap(find.text('Departments'));
      await tester.pumpAndSettle();

      expect(find.text('IT'), findsOneWidget);
      expect(find.text('2 employees'), findsOneWidget);
      expect(find.text('0 employees'), findsOneWidget);

      await tester.tap(find.text('Add department'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Sales');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verify(() => s.departments.create(name: 'Sales', description: '')).called(1);
      expect(find.text('New department'), findsNothing); // dialog closed
    });

    testWidgets('delete blocked by the server shows its message', (tester) async {
      final s = TestServices(signedInAs: adminUser);
      when(() => s.departments.delete('d1')).thenThrow(
        const ApiException('IT still has 2 employee(s). Reassign them before deleting.', statusCode: 409),
      );

      await pumpApp(tester, s);
      await tester.tap(find.text('Departments'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reassign them before deleting'), findsOneWidget);
    });
  });
}

Matcher _hasSearch(String search) => isA<EmployeeQuery>().having((q) => q.search, 'search', search);
