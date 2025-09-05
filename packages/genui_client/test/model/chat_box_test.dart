// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/src/model/chat_box.dart';

void main() {
  group('ChatBoxController', () {
    test('initial state is not waiting', () {
      final controller = ChatBoxController((_) {});
      expect(controller.isWaiting.value, isFalse);
    });

    test('setRequested sets waiting to true', () {
      final controller = ChatBoxController((_) {});
      controller.setRequested();
      expect(controller.isWaiting.value, isTrue);
    });

    test('setResponded sets waiting to false', () {
      final controller = ChatBoxController((_) {});
      controller.setRequested();
      controller.setResponded();
      expect(controller.isWaiting.value, isFalse);
    });

    test('onInput callback is called', () {
      String? receivedInput;
      final controller = ChatBoxController((input) {
        receivedInput = input;
      });
      controller.onInput('hello');
      expect(receivedInput, 'hello');
    });

    test('dispose disposes the notifier', () {
      final controller = ChatBoxController((_) {});
      controller.dispose();
      expect(
        () => controller.isWaiting.addListener(() {}),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('ChatBox widget', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      final controller = ChatBoxController((_) {});
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChatBox(controller))),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows progress indicator when waiting', (
      WidgetTester tester,
    ) async {
      final controller = ChatBoxController((_) {});
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChatBox(controller))),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);

      controller.setRequested();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.setResponded();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('calls onInput when text is submitted', (
      WidgetTester tester,
    ) async {
      String? submittedText;
      final controller = ChatBoxController((input) {
        submittedText = input;
      });

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChatBox(controller))),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(submittedText, 'hello');
      expect(find.widgetWithText(TextField, ''), findsOneWidget);
    });

    testWidgets('does not call onInput when text is empty', (
      WidgetTester tester,
    ) async {
      var called = false;
      final controller = ChatBoxController((_) {
        called = true;
      });

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChatBox(controller))),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(called, isFalse);
    });
  });
}
