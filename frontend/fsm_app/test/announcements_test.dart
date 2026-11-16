import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/models/announcement.dart';
import 'package:fsm_app/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  group('Announcement model', () {
    test('fromJson and permissions', () {
      final a = Announcement.fromJson({
        'id': 'a1',
        'title': 'Server maintenance',
        'message': 'Downtime Sunday',
        'category': 'maintenance',
        'pinned': true,
        'author': {'id': 'u2', 'name': 'Maya Manager', 'role': 'manager'},
        'createdAt': '2026-11-16T05:00:00.000Z',
        'updatedAt': '2026-11-16T07:00:00.000Z',
      });
      expect(a.category, AnnouncementCategory.maintenance);
      expect(a.pinned, isTrue);
      expect(a.wasEdited, isTrue);
      expect(a.canBeManagedBy(managerUser), isTrue); // author (u2)
      expect(a.canBeManagedBy(adminUser), isTrue);
      expect(a.canBeManagedBy(employeeUser), isFalse);
      expect(makeAnnouncement('b', author: adminUser).canBeManagedBy(managerUser), isFalse);
    });
  });

  testWidgets('dashboard shows the latest announcement and opens it', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    final a = makeAnnouncement('a1', pinned: true);
    stubAnnouncements(s, [a]);
    when(() => s.announcements.get('a1')).thenAnswer((_) async => a);

    await pumpApp(tester, s);
    expect(find.text('Latest announcement'), findsOneWidget);
    expect(find.text('Office closed Friday'), findsOneWidget);

    await tester.tap(find.text('Office closed Friday'));
    await tester.pumpAndSettle();
    expect(find.text('Announcement'), findsOneWidget);
    expect(find.text('Happy Diwali! The office is closed on Friday.'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing); // employees can't manage
  });

  testWidgets('employees browse and filter but cannot post', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    stubAnnouncements(s, [makeAnnouncement('a1'), makeAnnouncement('a2', title: 'Team meeting', category: AnnouncementCategory.meeting)]);

    await pumpApp(tester, s);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Team meeting'), findsOneWidget);
    expect(find.text('New announcement'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Meeting'));
    await tester.pumpAndSettle();
    verify(() => s.announcements.list(
          category: AnnouncementCategory.meeting,
          search: any(named: 'search'),
          page: 1,
          limit: any(named: 'limit'),
        )).called(1);
  });

  testWidgets('manager posts an announcement', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    final created = makeAnnouncement('a9', title: 'Safety drill');
    when(() => s.announcements.create(any())).thenAnswer((_) async => created);
    when(() => s.announcements.get('a9')).thenAnswer((_) async => created);

    await pumpApp(tester, s);
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('No announcements yet'), findsOneWidget);
    await tester.tap(find.text('New announcement'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Post announcement'));
    await tester.pump();
    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Message is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title *'), 'Safety drill');
    await tester.enterText(find.widgetWithText(TextFormField, 'Message *'), 'Fire drill at 3pm.');
    await tester.tap(find.text('Pin to top'));
    await tester.ensureVisible(find.text('Post announcement'));
    await tester.tap(find.text('Post announcement'));
    await tester.pumpAndSettle();

    final data = verify(() => s.announcements.create(captureAny())).captured.single as Map<String, dynamic>;
    expect(data, {'title': 'Safety drill', 'message': 'Fire drill at 3pm.', 'category': 'general', 'pinned': true});
    expect(find.textContaining('Everyone has been notified'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget); // the author can manage it
  });

  testWidgets("a manager sees no edit or delete on an admin's announcement", (tester) async {
    final s = TestServices(signedInAs: managerUser);
    final a = makeAnnouncement('a1', author: adminUser);
    stubAnnouncements(s, [a]);
    when(() => s.announcements.get('a1')).thenAnswer((_) async => a);

    await pumpApp(tester, s);
    await tester.tap(find.text('Office closed Friday'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets('employees are redirected from the create route', (tester) async {
    final s = TestServices(signedInAs: employeeUser);
    await pumpApp(tester, s);
    GoRouter.of(tester.element(find.byType(DashboardScreen))).go('/announcements/new');
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('admin deletes after confirming', (tester) async {
    final s = TestServices(signedInAs: adminUser);
    final a = makeAnnouncement('a1');
    stubAnnouncements(s, [a]);
    when(() => s.announcements.get('a1')).thenAnswer((_) async => a);
    when(() => s.announcements.delete('a1')).thenAnswer((_) async {});

    await pumpApp(tester, s);
    await tester.tap(find.text('Office closed Friday'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => s.announcements.delete('a1')).called(1);
    expect(find.text('Announcements'), findsWidgets); // back on the list
  });

  testWidgets('phone-sized announcement screens render without overflow', (tester) async {
    final s = TestServices(signedInAs: managerUser);
    final a = makeAnnouncement('a1', title: 'A very long announcement title that will need to be truncated', pinned: true);
    stubAnnouncements(s, [a]);
    when(() => s.announcements.get('a1')).thenAnswer((_) async => a);

    await pumpApp(tester, s, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('A very long').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
