import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/models/leave.dart';
import 'package:fsm_app/models/leave_query.dart';
import 'package:fsm_app/screens/dashboard/dashboard_screen.dart';
import 'package:fsm_app/services/leave_service.dart';

import 'helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  group('Leave models', () {
    test('fromJson keeps calendar dates and populated people', () {
      final l = LeaveRequest.fromJson({
        'id': 'l1',
        'user': {'id': 'u1', 'name': 'Priya Sharma', 'role': 'employee'},
        'leaveType': 'sick',
        'startDate': '2026-11-19T00:00:00.000Z',
        'endDate': '2026-11-23T00:00:00.000Z',
        'days': 3,
        'reason': 'Flu',
        'status': 'approved',
        'reviewedBy': {'id': 'u2', 'name': 'Maya'},
        'reviewedAt': '2026-11-17T05:00:00.000Z',
        'reviewNote': 'Get well',
      });
      expect(l.leaveType, LeaveType.sick);
      expect(l.status, LeaveStatus.approved);
      expect(l.startDate, DateTime(2026, 11, 19));
      expect(l.endDate, DateTime(2026, 11, 23));
      expect(l.reviewedBy!.name, 'Maya');
      expect(l.isSingleDay, isFalse);
    });

    test('working days skip weekends (same count as the backend)', () {
      expect(LeaveRequest.workingDaysBetween(DateTime(2026, 11, 19), DateTime(2026, 11, 23)), 3); // Thu-Mon
      expect(LeaveRequest.workingDaysBetween(DateTime(2026, 11, 21), DateTime(2026, 11, 22)), 0); // weekend
      expect(LeaveRequest.workingDaysBetween(DateTime(2026, 11, 16), DateTime(2026, 11, 16)), 1);
    });

    test('cancellable while pending, or approved and not yet started', () {
      final now = DateTime(2026, 11, 16, 10);
      expect(makeLeave('a', start: DateTime(2026, 11, 10)).canBeCancelled(now), isTrue);
      expect(makeLeave('b', status: LeaveStatus.approved, start: DateTime(2026, 11, 17)).canBeCancelled(now), isTrue);
      expect(makeLeave('c', status: LeaveStatus.approved, start: DateTime(2026, 11, 16)).canBeCancelled(now), isFalse);
      expect(makeLeave('d', status: LeaveStatus.rejected).canBeCancelled(now), isFalse);
    });

    test('query parameters', () {
      expect(const LeaveQuery(mine: true).toQueryParameters(), {'page': 1, 'limit': 10, 'mine': 'true'});
      final q = const LeaveQuery(status: LeaveStatus.pending).copyWith(leaveType: LeaveType.annual, page: 2);
      expect(q.toQueryParameters(), {'page': 2, 'limit': 10, 'status': 'pending', 'leaveType': 'annual'});
      expect(q.copyWith(status: null).status, isNull);
    });

    test('LeaveService.apply sends date-only strings', () async {
      final api = MockApiService();
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer((_) async => {
            'data': {
              'leave': {
                'id': 'l1',
                'leaveType': 'annual',
                'startDate': '2026-12-01T00:00:00.000Z',
                'endDate': '2026-12-02T00:00:00.000Z',
                'days': 2,
                'reason': 'Trip',
              },
            },
          });

      final leave = await LeaveService(api).apply(
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 2),
        reason: 'Trip',
      );

      final data = verify(() => api.post('/leaves', data: captureAny(named: 'data'))).captured.single as Map;
      expect(data, {'leaveType': 'annual', 'startDate': '2026-12-01', 'endDate': '2026-12-02', 'reason': 'Trip'});
      expect(leave.days, 2);
    });
  });

  Future<void> openLeave(WidgetTester tester) async {
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
  }

  group('My leave', () {
    testWidgets('lists own requests; employees have no review queue', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.leaves.list(any())).thenAnswer((_) async => pageOf([makeLeave('l1'), makeLeave('l2', status: LeaveStatus.approved)]));

      await pumpApp(tester, s);
      await openLeave(tester);

      expect(find.text('My leave'), findsOneWidget);
      expect(find.text('Requests'), findsNothing);
      expect(find.text('Casual leave'), findsNWidgets(2));
      expect(find.textContaining('3 working days'), findsNWidgets(2));
      verify(() => s.leaves.list(any(that: predicate<LeaveQuery>((q) => q.mine)))).called(1);
    });

    testWidgets('apply form validates before sending', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.leaves.list(any())).thenAnswer((_) async => pageOf(<LeaveRequest>[]));

      await pumpApp(tester, s);
      await openLeave(tester);
      expect(find.text('No leave requests yet'), findsOneWidget);
      await tester.tap(find.text('Apply for leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit request'));
      await tester.pump();
      expect(find.text('Choose your leave dates'), findsOneWidget);
      expect(find.text('Reason is required'), findsOneWidget);
      verifyNever(() => s.leaves.apply(
            leaveType: any(named: 'leaveType'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            reason: any(named: 'reason'),
          ));

      // Sick leave explains that past days are allowed.
      await tester.tap(find.text('Casual leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sick leave').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('recorded for past days'), findsOneWidget);
    });

    testWidgets('requester sees "waiting" and can cancel a pending request', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      var leave = makeLeave('l1');
      when(() => s.leaves.list(any())).thenAnswer((_) async => pageOf([leave]));
      when(() => s.leaves.get('l1')).thenAnswer((_) async => leave);
      when(() => s.leaves.cancel('l1')).thenAnswer((_) async {
        leave = makeLeave('l1', status: LeaveStatus.cancelled);
        return leave;
      });

      await pumpApp(tester, s);
      await openLeave(tester);
      await tester.tap(find.text('Casual leave'));
      await tester.pumpAndSettle();

      expect(find.text('Leave request'), findsOneWidget);
      expect(find.text('Approve'), findsNothing); // can't review your own
      expect(find.text('Family function'), findsOneWidget);

      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();

      verify(() => s.leaves.cancel('l1')).called(1);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancel request'), findsNothing);
    });

    testWidgets('employees are redirected away from the review queue', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      await pumpApp(tester, s);
      GoRouter.of(tester.element(find.byType(DashboardScreen))).go('/leave/requests');
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  group('Review queue', () {
    testWidgets('manager sees pending requests and approves with a note', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      var leave = makeLeave('l1');
      when(() => s.leaves.list(any())).thenAnswer((inv) async {
        final q = inv.positionalArguments.first as LeaveQuery;
        return q.mine ? pageOf(<LeaveRequest>[]) : pageOf([leave]);
      });
      when(() => s.leaves.get('l1')).thenAnswer((_) async => leave);
      when(() => s.leaves.approve('l1', note: any(named: 'note'))).thenAnswer((_) async {
        leave = makeLeave('l1', status: LeaveStatus.approved);
        return leave;
      });

      await pumpApp(tester, s);
      await openLeave(tester);
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      expect(find.text('Leave requests'), findsOneWidget);
      verify(() => s.leaves.list(any(that: predicate<LeaveQuery>((q) => !q.mine && q.status == LeaveStatus.pending)))).called(1);
      expect(find.text('Eli Employee'), findsOneWidget);

      await tester.tap(find.text('Eli Employee'));
      await tester.pumpAndSettle();
      expect(find.text('Requested by'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve leave?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Enjoy!');
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
      await tester.pumpAndSettle();

      verify(() => s.leaves.approve('l1', note: 'Enjoy!')).called(1);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets("managers can't review another manager's request", (tester) async {
      final s = TestServices(signedInAs: managerUser);
      final leave = makeLeave('l9', requester: adminUser);
      when(() => s.leaves.list(any())).thenAnswer((_) async => pageOf([leave]));
      when(() => s.leaves.get('l9')).thenAnswer((_) async => leave);

      await pumpApp(tester, s);
      await openLeave(tester);
      await tester.tap(find.text('Casual leave'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });
  });

  testWidgets('phone-sized leave screens render without overflow', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    final leave = makeLeave('l1', type: LeaveType.annual);
    when(() => s.leaves.list(any())).thenAnswer((_) async => pageOf([leave], total: 25));
    when(() => s.leaves.get('l1')).thenAnswer((_) async => leave);

    await pumpApp(tester, s, size: const Size(360, 740));
    await openLeave(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Eli Employee'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
