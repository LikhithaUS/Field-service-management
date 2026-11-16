import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fsm_app/widgets/password_field.dart';

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      if (call.method == 'Clipboard.hasStrings') return {'value': clipboard != null};
      return null;
    });
  });

  Future<TextEditingController> pumpField(WidgetTester tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [PasswordField(controller: controller), PasswordRequirements(controller: controller)]),
      ),
    ));
    return controller;
  }

  testWidgets('checklist ticks off each rule as the user types', (tester) async {
    await pumpField(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // lowercase only

    await tester.enterText(find.byType(TextFormField), 'Likhitha@2026');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
  });

  testWidgets('hidden password can be copied, cut and pasted with the keyboard', (tester) async {
    final controller = await pumpField(tester);
    await tester.enterText(find.byType(TextFormField), 'Secret@123');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboard, 'Secret@123');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.text, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.text, 'Secret@123');
  });

  testWidgets('right-click menu offers Copy and Paste on the hidden field', (tester) async {
    final controller = await pumpField(tester);
    await tester.enterText(find.byType(TextFormField), 'Secret@123');
    await tester.pump();

    await tester.tap(find.byType(EditableText), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, 'Secret@123');
    expect(controller.text, 'Secret@123');
  });
}
