import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/core/utils/formatters.dart';
import 'package:fsm_app/models/app_notification.dart';
import 'package:fsm_app/screens/notifications/notifications_screen.dart';

import 'helpers.dart';

AppNotification note(
  String id, {
  String title = 'New task assigned',
  NotificationType type = NotificationType.taskAssigned,
  String? entityType = 'task',
  String? entityId = 't1',
  bool isRead = false,
}) =>
    AppNotification(
      id: id,
      title: title,
      message: 'Maya Manager assigned you TSK-0001: Job 1',
      type: type,
      entityType: entityType,
      entityId: entityId,
      isRead: isRead,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

void main() {
  setUpAll(registerTestFallbacks);

  group('Notification model and helpers', () {
    test('fromJson parses type and link', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Leave approved',
        'message': 'Maya approved your leave',
        'type': 'leave_decision',
        'entityType': 'leave',
        'entityId': 'l1',
        'isRead': false,
        'createdAt': '2026-11-16T05:00:00.000Z',
      });
      expect(n.type, NotificationType.leaveDecision);
      expect(notificationRoute(n), '/leave/l1');
      expect(n.markedRead().isRead, isTrue);
      expect(notificationRoute(note('x', entityType: null, entityId: null)), isNull);
      expect(notificationRoute(note('y')), '/tasks/t1');
    });

    test('relative time', () {
      final now = DateTime(2026, 11, 16, 12);
      expect(Formatters.relative(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(Formatters.relative(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(Formatters.relative(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(Formatters.relative(now.subtract(const Duration(days: 1, hours: 2)), now: now), 'Yesterday');
      expect(Formatters.relative(now.subtract(const Duration(days: 4)), now: now), '4d ago');
      expect(Formatters.relative(DateTime(2026, 10, 1), now: now), '01 Oct 2026');
    });
  });

  testWidgets('dashboard bell shows the unread count and opens notifications', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    when(() => s.notifications.unreadCount()).thenAnswer((_) async => 3);
    when(() => s.notifications.list(page: any(named: 'page'), unreadOnly: any(named: 'unreadOnly')))
        .thenAnswer((_) async => pageOf([note('n1'), note('n2', title: 'Task completed', isRead: true)]));

    await pumpApp(tester, s);
    expect(find.byTooltip('Notifications (3 unread)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications (3 unread)'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New task assigned'), findsOneWidget);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.textContaining('5m ago'), findsNWidgets(2));
    expect(find.text('Unread only (3)'), findsOneWidget);
  });

  testWidgets('tapping an unread notification marks it read and opens the task', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    var unread = 1;
    when(() => s.notifications.unreadCount()).thenAnswer((_) async => unread);
    when(() => s.notifications.list(page: any(named: 'page'), unreadOnly: any(named: 'unreadOnly')))
        .thenAnswer((_) async => pageOf([note('n1', isRead: unread == 0)]));
    when(() => s.notifications.markRead('n1')).thenAnswer((_) async => unread = 0);
    when(() => s.tasks.get('t1')).thenAnswer((_) async => makeTask(1));
    when(() => s.tasks.comments('t1')).thenAnswer((_) async => []);

    await pumpApp(tester, s);
    await tester.tap(find.text('Notifications')); // dashboard tile
    await tester.pumpAndSettle();
    await tester.tap(find.text('New task assigned'));
    await tester.pumpAndSettle();

    verify(() => s.notifications.markRead('n1')).called(1);
    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('Job 1'), findsOneWidget);

    // Back on the dashboard the badge has refreshed.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
  });

  testWidgets('mark all read and the unread-only filter', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    var unread = 2;
    when(() => s.notifications.unreadCount()).thenAnswer((_) async => unread);
    when(() => s.notifications.list(page: any(named: 'page'), unreadOnly: any(named: 'unreadOnly'))).thenAnswer((inv) async {
      final onlyUnread = inv.namedArguments[#unreadOnly] as bool;
      if (onlyUnread && unread == 0) return pageOf(<AppNotification>[]);
      return pageOf([note('n1', isRead: unread == 0), note('n2', type: NotificationType.leaveRequested, entityType: 'leave', isRead: unread == 0)]);
    });
    when(() => s.notifications.markAllRead()).thenAnswer((_) async => unread = 0);

    await pumpApp(tester, s);
    await tester.tap(find.byTooltip('Notifications (2 unread)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    verify(() => s.notifications.markAllRead()).called(1);

    await tester.tap(find.text('Unread only'));
    await tester.pumpAndSettle();
    verify(() => s.notifications.list(page: 1, unreadOnly: true)).called(1);
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('phone-sized notifications screen renders without overflow', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    when(() => s.notifications.unreadCount()).thenAnswer((_) async => 120);
    when(() => s.notifications.list(page: any(named: 'page'), unreadOnly: any(named: 'unreadOnly')))
        .thenAnswer((_) async => pageOf([for (var i = 0; i < 5; i++) note('n$i')], total: 120));

    await pumpApp(tester, s, size: const Size(360, 740));
    expect(find.text('99+'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications (120 unread)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
