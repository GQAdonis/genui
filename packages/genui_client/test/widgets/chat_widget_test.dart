// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';

class FakeSurfaceBuilder implements SurfaceBuilder {
  @override
  final catalog = const Catalog([]);

  @override
  Stream<GenUiUpdate> get updates => const Stream.empty();

  @override
  final valueStore = WidgetValueStore();

  final Map<String, ValueNotifier<UiDefinition?>> _surfaces = {};

  @override
  ValueNotifier<UiDefinition?> surface(String surfaceId) {
    return _surfaces.putIfAbsent(surfaceId, () => ValueNotifier(null));
  }
}

class FakeUiAgent implements UiAgent {
  final _conversation = ValueNotifier<List<ChatMessage>>([]);
  final _isProcessing = ValueNotifier<bool>(false);
  final _builder = FakeSurfaceBuilder();
  UserMessage? lastRequest;

  @override
  SurfaceBuilder get builder => _builder;

  @override
  ValueNotifier<List<ChatMessage>> get conversation => _conversation;

  @override
  ValueNotifier<bool> get isProcessing => _isProcessing;

  @override
  Future<void> sendRequest(UserMessage message) async {
    lastRequest = message;
    _isProcessing.value = true;
    _conversation.value = [..._conversation.value, message];
    _isProcessing.value = false;
  }

  @override
  Future<void> sendUiEvents(List<UiEvent> events) async {
    final message = UserMessage(events.map(UiEventPart.new).toList());
    return sendRequest(message);
  }

  @override
  ValueNotifier<UiDefinition?> surface(String surfaceId) {
    return _builder.surface(surfaceId);
  }

  @override
  Stream<GenUiUpdate> get updates => const Stream.empty();

  @override
  void dispose() {
    _conversation.dispose();
    _isProcessing.dispose();
  }
}

void main() {
  group('GenUiChat', () {
    late FakeUiAgent fakeAgent;

    setUp(() {
      fakeAgent = FakeUiAgent();
    });

    tearDown(() {
      fakeAgent.dispose();
    });

    Widget buildTestWidget({bool showInternal = false}) {
      return MaterialApp(
        home: Scaffold(
          body: GenUiChat(
            agent: fakeAgent,
            onEvent: (_) {},
            showInternalMessages: showInternal,
          ),
        ),
      );
    }

    testWidgets('renders chat box and empty message list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(ChatBox), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays user and AI text messages', (
      WidgetTester tester,
    ) async {
      fakeAgent.conversation.value = [
        UserMessage.text('Hello'),
        AiTextMessage.text('Hi there'),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // For ValueListenableBuilder

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi there'), findsOneWidget);
    });

    testWidgets('displays AI UI message', (WidgetTester tester) async {
      final uiMessage = AiUiMessage(
        surfaceId: 's1',
        definition: {'root': 'r1', 'widgets': []},
      );
      fakeAgent.conversation.value = [uiMessage];
      fakeAgent.surface('s1').value = UiDefinition.fromMap({
        'surfaceId': 's1',
        'root': 'r1',
        'widgets': [],
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(GenUiSurface), findsOneWidget);
    });

    testWidgets('sends user input to agent', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'test input');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(fakeAgent.lastRequest, isA<UserMessage>());
      final textPart = fakeAgent.lastRequest!.parts.first as TextPart;
      expect(textPart.text, 'test input');
    });

    testWidgets('hides internal messages by default', (
      WidgetTester tester,
    ) async {
      fakeAgent.conversation.value = [
        const InternalMessage('internal'),
        const ToolResponseMessage([]),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.textContaining('Internal message:'), findsNothing);
    });

    testWidgets(
      'updates chat box waiting state based on agent processing state',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Start processing
        fakeAgent.isProcessing.value = true;
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // End processing
        fakeAgent.isProcessing.value = false;
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });
}
