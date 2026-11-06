import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/app.dart';
import 'package:fsm_app/core/exceptions/api_exception.dart';
import 'package:fsm_app/models/user.dart';
import 'package:fsm_app/providers/service_providers.dart';
import 'package:fsm_app/services/api_service.dart';
import 'package:fsm_app/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockApiService extends Mock implements ApiService {}

const _user = User(id: '1', name: 'Asha Rao', email: 'asha@example.com', role: UserRole.manager);

void main() {
  late MockAuthService auth;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        apiServiceProvider.overrideWithValue(MockApiService()),
      ],
      child: const ServiceHubApp(),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    auth = MockAuthService();
  });

  testWidgets('no stored session -> splash redirects to login', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await pumpApp(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('restored session -> goes straight to dashboard', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => _user);
    await pumpApp(tester);
    expect(find.text('Welcome back, Asha'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
  });

  testWidgets('server unreachable on startup -> splash shows retry', (tester) async {
    when(() => auth.currentUser()).thenThrow(const ApiException('Cannot reach the server.'));
    await pumpApp(tester);
    expect(find.text('Cannot reach the server.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('login form validates before calling the API', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await pumpApp(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(() => auth.login(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('wrong credentials show the server message', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    when(() => auth.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const ApiException('Invalid email or password', statusCode: 401));
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget); // still on login
  });

  testWidgets('successful login -> dashboard, logout -> login', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    when(() => auth.login(email: 'asha@example.com', password: 'secret123')).thenAnswer((_) async => _user);
    when(() => auth.logout()).thenAnswer((_) async {});
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Asha'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    verify(() => auth.logout()).called(1);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('can navigate to register and back', (tester) async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);
    await pumpApp(tester);

    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
