import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fsm_app/core/exceptions/api_exception.dart';

import 'helpers.dart';

void main() {
  late TestServices services;

  setUp(() => services = TestServices());

  Future<void> openForgotPassword(WidgetTester tester) async {
    await pumpApp(tester, services);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget); // screen title
  }

  testWidgets('request a code, then reset and get signed in', (tester) async {
    when(() => services.auth.forgotPassword('asha@example.com')).thenAnswer((_) async => 'sent');
    when(() => services.auth.resetPassword(email: 'asha@example.com', code: '123456', password: 'NewPass@123'))
        .thenAnswer((_) async => adminUser);

    await openForgotPassword(tester);
    await tester.enterText(find.byType(TextFormField), 'asha@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    // Reset screen opens with the email pre-filled.
    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'asha@example.com'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'NewPass@123');
    await tester.enterText(fields.at(3), 'NewPass@123');
    await tester.tap(find.text('Set password & sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Root'), findsOneWidget);
  });

  testWidgets('"I already have a code" goes straight to the reset screen', (tester) async {
    await openForgotPassword(tester);
    await tester.tap(find.text('I already have a code'));
    await tester.pumpAndSettle();
    expect(find.text('Set a new password'), findsOneWidget);
    verifyNever(() => services.auth.forgotPassword(any()));
  });

  testWidgets('validates the code and passwords locally', (tester) async {
    await openForgotPassword(tester);
    await tester.tap(find.text('I already have a code'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'asha@example.com');
    await tester.enterText(fields.at(1), '12');
    await tester.enterText(fields.at(2), 'NewPass@123');
    await tester.enterText(fields.at(3), 'different1');
    await tester.tap(find.text('Set password & sign in'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('shows the server error for a bad code', (tester) async {
    when(() => services.auth.resetPassword(email: any(named: 'email'), code: any(named: 'code'), password: any(named: 'password')))
        .thenThrow(const ApiException('Invalid or expired code', statusCode: 400));

    await openForgotPassword(tester);
    await tester.tap(find.text('I already have a code'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'asha@example.com');
    await tester.enterText(fields.at(1), '999999');
    await tester.enterText(fields.at(2), 'NewPass@123');
    await tester.enterText(fields.at(3), 'NewPass@123');
    await tester.tap(find.text('Set password & sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid or expired code'), findsOneWidget);
    expect(find.text('Set a new password'), findsOneWidget);
  });
}
