// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'ui_agent_test.mocks.dart';

@GenerateMocks([GenUiManager, GenUIClient])
void main() {
  group('UiAgent', () {
    late MockGenUiManager mockManager;
    late MockGenUIClient mockClient;
    late UiAgent agent;

    setUp(() {
      mockManager = MockGenUiManager();
      mockClient = MockGenUIClient();
      agent = UiAgent(genUiManager: mockManager, client: mockClient);

      when(mockManager.updates).thenAnswer((_) => const Stream.empty());
      when(mockManager.catalog).thenReturn(const Catalog([]));
    });

    test('constructor creates default manager and client if not provided', () {
      final defaultAgent = UiAgent();
      expect(defaultAgent.builder, isA<GenUiManager>());
    });

    test('initial state', () {
      expect(agent.conversation.value, isEmpty);
      expect(agent.isProcessing.value, isFalse);
    });

    test('sendRequest adds user message and sets processing state', () async {
      final message = UserMessage.text('hello');
      when(
        mockClient.generateUI(any, any),
      ).thenAnswer((_) => Stream.fromIterable([]));

      final future = agent.sendRequest(message);

      expect(agent.conversation.value, [message]);
      expect(agent.isProcessing.value, isTrue);

      await future;

      expect(agent.isProcessing.value, isFalse);
    });

    test('sendRequest handles AiUiMessage from client', () async {
      final userMessage = UserMessage.text('hello');
      final uiMessage = AiUiMessage(
        surfaceId: 's1',
        definition: {'root': 'r1'},
      );
      when(
        mockClient.generateUI(any, any),
      ).thenAnswer((_) => Stream.value(uiMessage));

      await agent.sendRequest(userMessage);

      verify(mockManager.addOrUpdateSurface('s1', {'root': 'r1'})).called(1);
      expect(agent.conversation.value.contains(uiMessage), isTrue);
    });

    test('sendRequest handles AiTextMessage from client', () async {
      final userMessage = UserMessage.text('hello');
      final textMessage = AiTextMessage.text('world');
      when(
        mockClient.generateUI(any, any),
      ).thenAnswer((_) => Stream.value(textMessage));

      await agent.sendRequest(userMessage);

      expect(agent.conversation.value.contains(textMessage), isTrue);
    });

    test(
      'sendRequest updates existing AiUiMessage instead of adding new one',
      () async {
        final userMessage = UserMessage.text('hello');
        final uiMessage1 = AiUiMessage(
          surfaceId: 's1',
          definition: {'root': 'r1'},
        );
        final uiMessage2 = AiUiMessage(
          surfaceId: 's1',
          definition: {'root': 'r2'},
        );

        // First, add an existing UI message to the conversation.
        agent.conversation.value.add(uiMessage1);

        when(
          mockClient.generateUI(any, any),
        ).thenAnswer((_) => Stream.value(uiMessage2));

        await agent.sendRequest(userMessage);

        verify(mockManager.addOrUpdateSurface('s1', {'root': 'r2'})).called(1);
        // The original uiMessage1 should still be there, not a new one.
        expect(agent.conversation.value.whereType<AiUiMessage>().length, 1);
        expect(agent.conversation.value.contains(uiMessage1), isTrue);
        expect(agent.conversation.value.contains(uiMessage2), isFalse);
      },
    );

    test('sendRequest sets processing to false on error', () async {
      final message = UserMessage.text('hello');
      when(
        mockClient.generateUI(any, any),
      ).thenAnswer((_) => Stream.error(Exception('error')));

      await expectLater(agent.sendRequest(message), throwsException);

      expect(agent.isProcessing.value, isFalse);
    });

    test('sendUiEvents creates and sends a UserMessage', () async {
      final event = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onTap',
      );
      when(
        mockClient.generateUI(any, any),
      ).thenAnswer((_) => Stream.fromIterable([]));

      await agent.sendUiEvents([event]);

      final sentMessage = agent.conversation.value.firstWhere(
        (m) => m is UserMessage,
      );
      expect(sentMessage, isA<UserMessage>());
      final userMessage = sentMessage as UserMessage;
      expect(userMessage.parts.length, 1);
      expect(userMessage.parts.first, isA<UiEventPart>());
      final eventPart = userMessage.parts.first as UiEventPart;
      expect(eventPart.event.surfaceId, 's1');
    });

    test('dispose calls manager dispose', () {
      agent.dispose();
      verify(mockManager.dispose()).called(1);
    });
  });
}
