import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/core/exceptions/api_exception.dart';
import 'package:fsm_app/core/utils/api_dates.dart';
import 'package:fsm_app/core/utils/formatters.dart';
import 'package:fsm_app/models/attendance.dart';
import 'package:fsm_app/models/attendance_query.dart';
import 'package:fsm_app/models/employee.dart';
import 'package:fsm_app/models/person_ref.dart';
import 'package:fsm_app/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

DateTime get _today => DateUtils.dateOnly(DateTime.now());

AttendanceRecord record({
  String id = 'a1',
  DateTime? date,
  DateTime? checkIn,
  DateTime? checkOut,
  int minutes = 0,
  AttendanceStatus status = AttendanceStatus.present,
  PersonRef? user,
}) =>
    AttendanceRecord(
      id: id,
      date: date ?? _today,
      checkIn: checkIn,
      checkOut: checkOut,
      workingMinutes: minutes,
      status: status,
      user: user,
    );

void main() {
  setUpAll(registerTestFallbacks);

  group('Attendance models', () {
    test('AttendanceRecord.fromJson keeps the work day and converts moments to local time', () {
      final r = AttendanceRecord.fromJson({
        'id': 'a1',
        'date': '2026-11-16T00:00:00.000Z',
        'user': {'id': 'u1', 'name': 'Priya Sharma'},
        'checkIn': '2026-11-16T03:26:00.000Z',
        'checkOut': '2026-11-16T12:12:00.000Z',
        'workingMinutes': 526,
        'status': 'half_day',
      });
      expect(r.date, DateTime(2026, 11, 16));
      expect(r.checkIn, DateTime.utc(2026, 11, 16, 3, 26).toLocal());
      expect(r.status, AttendanceStatus.halfDay);
      expect(r.user!.name, 'Priya Sharma');
      expect(Formatters.duration(r.worked()), '8h 46m');
    });

    test('worked time counts live until check-out; missed check-out on earlier days', () {
      final checkIn = DateTime(2026, 11, 16, 9);
      final open = record(date: DateTime(2026, 11, 16), checkIn: checkIn);
      expect(open.isCheckedIn, isTrue);
      expect(open.worked(DateTime(2026, 11, 16, 11, 30)), const Duration(hours: 2, minutes: 30));
      expect(open.missedCheckOut(DateTime(2026, 11, 16, 20)), isFalse);
      expect(open.missedCheckOut(DateTime(2026, 11, 17, 8)), isTrue);
    });

    test('AttendanceToday decides which button to show', () {
      final before = AttendanceToday.fromJson({
        'date': '2026-11-16T00:00:00.000Z',
        'attendance': null,
        'rules': {'timeZone': 'Asia/Kolkata', 'workStart': '10:00', 'halfDayHours': 5},
      });
      expect(before.canCheckIn, isTrue);
      expect(before.canCheckOut, isFalse);
      expect(before.rules.workStart, '10:00');

      final working = AttendanceToday(date: _today, record: record(checkIn: DateTime.now()));
      expect(working.canCheckIn, isFalse);
      expect(working.canCheckOut, isTrue);

      final done = AttendanceToday(date: _today, record: record(checkIn: DateTime.now(), checkOut: DateTime.now()));
      expect(done.canCheckIn || done.canCheckOut, isFalse);
    });

    test('summary and query parameters', () {
      final s = AttendanceSummary.fromJson({'present': 10, 'late': 2, 'half_day': 1, 'totalMinutes': 6000});
      expect(s.daysWorked, 13);
      expect(s.halfDay, 1);

      final q = AttendanceQuery.thisMonth(DateTime(2026, 11, 16, 15));
      expect(q.toQueryParameters(), {'page': 1, 'limit': 10, 'from': '2026-11-01', 'to': '2026-11-16'});
      final filtered = q.copyWith(status: AttendanceStatus.late, person: const PersonRef(id: 'u9', name: 'X'));
      expect(filtered.toQueryParameters()['status'], 'late');
      expect(filtered.toQueryParameters()['user'], 'u9');
      expect(filtered.copyWith(person: null).person, isNull);
      expect(AttendanceQuery.today(DateTime(2026, 1, 5, 10)).isSingleDay, isTrue);
      expect(ApiDates.toDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(Formatters.duration(const Duration(minutes: 45)), '45m');
    });
  });

  Future<void> openAttendance(WidgetTester tester) async {
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
  }

  group('My attendance', () {
    testWidgets('check in, then check out after confirming', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      final checkInAt = DateTime.now().subtract(const Duration(hours: 2));
      var today = AttendanceToday(date: _today);
      when(() => s.attendance.today()).thenAnswer((_) async => today);
      when(() => s.attendance.list(any())).thenAnswer((_) async => historyOf([]));
      when(() => s.attendance.checkIn()).thenAnswer((_) async {
        today = AttendanceToday(date: _today, record: record(checkIn: checkInAt));
        return today.record!;
      });
      when(() => s.attendance.checkOut()).thenAnswer((_) async {
        today = AttendanceToday(
          date: _today,
          record: record(checkIn: checkInAt, checkOut: DateTime.now(), minutes: 120, status: AttendanceStatus.halfDay),
        );
        return today.record!;
      });

      await pumpApp(tester, s);
      await openAttendance(tester);

      expect(find.text('Team report'), findsNothing); // employees have no report
      expect(find.text('No attendance this month yet'), findsOneWidget);
      expect(find.textContaining('Work starts at 09:30'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      verify(() => s.attendance.checkIn()).called(1);
      expect(find.textContaining('Checked in at'), findsOneWidget);
      expect(find.text('Check out'), findsWidgets);
      expect(find.text('2h 00m'), findsOneWidget); // live "Worked"

      await tester.tap(find.widgetWithText(FilledButton, 'Check out'));
      await tester.pumpAndSettle();
      expect(find.text('Check out now?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Check out').last);
      await tester.pumpAndSettle();

      verify(() => s.attendance.checkOut()).called(1);
      expect(find.text("You're done for today"), findsOneWidget);
      expect(find.text('Half day'), findsOneWidget);
    });

    testWidgets('history shows times, missed check-outs and the summary', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      final yesterday = _today.subtract(const Duration(days: 1));
      final twoDaysAgo = _today.subtract(const Duration(days: 2));
      when(() => s.attendance.today()).thenAnswer((_) async => AttendanceToday(date: _today));
      when(() => s.attendance.list(any())).thenAnswer((_) async => historyOf(
            [
              record(id: 'a1', date: yesterday, checkIn: yesterday.add(const Duration(hours: 10)), status: AttendanceStatus.late),
              record(
                id: 'a2',
                date: twoDaysAgo,
                checkIn: twoDaysAgo.add(const Duration(hours: 9)),
                checkOut: twoDaysAgo.add(const Duration(hours: 17, minutes: 30)),
                minutes: 510,
              ),
            ],
            summary: const AttendanceSummary(present: 1, late: 1, totalMinutes: 510),
          ));

      await pumpApp(tester, s);
      await openAttendance(tester);

      expect(find.textContaining('Missed check-out'), findsOneWidget);
      expect(find.textContaining('Out 17:30 · 8h 30m'), findsOneWidget);
      expect(find.text('8h 30m'), findsOneWidget); // summary hours
      expect(find.text('Late'), findsWidgets);
    });

    testWidgets('a failed check-in shows the server message', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      when(() => s.attendance.today()).thenAnswer((_) async => AttendanceToday(date: _today));
      when(() => s.attendance.list(any())).thenAnswer((_) async => historyOf([]));
      when(() => s.attendance.checkIn())
          .thenThrow(const ApiException('You have already checked in today', statusCode: 409));

      await pumpApp(tester, s);
      await openAttendance(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(find.text('You have already checked in today'), findsOneWidget);
    });

    testWidgets('employees are redirected away from the team report', (tester) async {
      final s = TestServices(signedInAs: employeeUser);
      await pumpApp(tester, s);

      GoRouter.of(tester.element(find.byType(DashboardScreen))).go('/attendance/report');
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  group('Team report', () {
    testWidgets('staff see everyone for today and can filter by person and status', (tester) async {
      final s = TestServices(signedInAs: managerUser);
      const priya = PersonRef(id: 'u7', name: 'Priya Sharma');
      when(() => s.attendance.today()).thenAnswer((_) async => AttendanceToday(date: _today));
      when(() => s.attendance.list(any())).thenAnswer((inv) async {
        final q = inv.positionalArguments.first as AttendanceQuery;
        if (q.isSingleDay) {
          return historyOf([
            record(id: 'r1', checkIn: _today.add(const Duration(hours: 9)), user: priya),
            record(id: 'r2', checkIn: _today.add(const Duration(hours: 10)), status: AttendanceStatus.late, user: personFrom(employeeUser)),
          ], summary: const AttendanceSummary(present: 1, late: 1));
        }
        return historyOf([]);
      });
      when(() => s.employees.list(any())).thenAnswer((_) async => pageOf([
            const Employee(id: 'e7', employeeId: 'EMP-0007', name: 'Priya Sharma', email: 'p@example.com', userId: 'u7'),
          ]));

      await pumpApp(tester, s);
      await openAttendance(tester);
      await tester.tap(find.text('Team report'));
      await tester.pumpAndSettle();

      expect(find.text('Team attendance'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Eli Employee'), findsOneWidget);
      expect(find.text(Formatters.date(_today)), findsOneWidget); // range button

      // Filter to one person via the shared picker.
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priya Sharma').last);
      await tester.pumpAndSettle();
      verify(() => s.attendance.list(any(that: predicate<AttendanceQuery>((q) => q.person?.id == 'u7')))).called(1);
      expect(find.text('Reset'), findsOneWidget);

      // Status filter.
      await tester.tap(find.text('All statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Late').last);
      await tester.pumpAndSettle();
      verify(() => s.attendance.list(any(that: predicate<AttendanceQuery>((q) => q.status == AttendanceStatus.late)))).called(1);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Everyone'), findsOneWidget);
    });
  });

  testWidgets('phone-sized attendance screens render without overflow', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    when(() => s.attendance.today())
        .thenAnswer((_) async => AttendanceToday(date: _today, record: record(checkIn: DateTime.now(), status: AttendanceStatus.late)));
    when(() => s.attendance.list(any())).thenAnswer((_) async => historyOf(
          [record(checkIn: DateTime.now(), user: personFrom(employeeUser))],
          summary: const AttendanceSummary(present: 12, late: 3, halfDay: 1, totalMinutes: 7000),
        ));

    await pumpApp(tester, s, size: const Size(360, 740));
    await openAttendance(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Team report'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
