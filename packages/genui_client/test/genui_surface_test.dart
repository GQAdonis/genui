// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';
import 'package:genui_client/src/widgets/column.dart';
import 'package:genui_client/src/widgets/elevated_button.dart';
import 'package:genui_client/src/widgets/text.dart';

void main() {
  group('GenUiSurface', () {
    late GenUiManager manager;

    setUp(() {
      final catalog = Catalog([text, elevatedButton, column]);
      manager = GenUiManager(catalog: catalog);
    });

    tearDown(() {
      manager.dispose();
    });

    testWidgets('builds UI from definition', (WidgetTester tester) async {
      const surfaceId = 'test_surface';
      final definition = {
        'root': 'root_column',
        'widgets': [
          {
            'id': 'root_column',
            'widget': {
              'Column': {
                'children': ['text1', 'button1'],
              },
            },
          },
          {
            'id': 'text1',
            'widget': {
              'Text': {'text': 'Hello'},
            },
          },
          {
            'id': 'button1',
            'widget': {
              'ElevatedButton': {'child': 'button_text'},
            },
          },
          {
            'id': 'button_text',
            'widget': {
              'Text': {'text': 'Tap me'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, definition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: surfaceId,
              onEvent: (event) {},
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Tap me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('rebuilds on surface update', (WidgetTester tester) async {
      const surfaceId = 'test_surface';
      final initialDefinition = {
        'root': 'text1',
        'widgets': [
          {
            'id': 'text1',
            'widget': {
              'Text': {'text': 'Initial'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, initialDefinition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: surfaceId,
              onEvent: (event) {},
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
      expect(find.text('Updated'), findsNothing);

      final updatedDefinition = {
        'root': 'text1',
        'widgets': [
          {
            'id': 'text1',
            'widget': {
              'Text': {'text': 'Updated'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, updatedDefinition);
      await tester.pump();

      expect(find.text('Initial'), findsNothing);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('dispatches event on interaction', (WidgetTester tester) async {
      const surfaceId = 'test_surface';
      final definition = {
        'root': 'button1',
        'widgets': [
          {
            'id': 'button1',
            'widget': {
              'ElevatedButton': {'child': 'button_text'},
            },
          },
          {
            'id': 'button_text',
            'widget': {
              'Text': {'text': 'Tap me'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, definition);

      UiEvent? receivedEvent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: surfaceId,
              onEvent: (event) {
                receivedEvent = event;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.surfaceId, surfaceId);
      expect(receivedEvent!.widgetId, 'button1');
      expect(receivedEvent!.eventType, 'onTap');
      expect(receivedEvent!.isAction, isTrue);
    });

    testWidgets('uses defaultBuilder when definition is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: 'non_existent_surface',
              onEvent: (event) {},
              defaultBuilder: (context) => const Text('Default'),
            ),
          ),
        ),
      );

      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('handles empty widget list', (WidgetTester tester) async {
      const surfaceId = 'test_surface';
      final definition = {'root': 'root1', 'widgets': []};
      manager.addOrUpdateSurface(surfaceId, definition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: surfaceId,
              onEvent: (event) {},
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('handles root widget not found', (WidgetTester tester) async {
      const surfaceId = 'test_surface';
      final definition = {
        'root': 'non_existent_root',
        'widgets': [
          {
            'id': 'widget1',
            'widget': {
              'Text': {'text': 'Hello'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, definition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(
              builder: manager,
              surfaceId: surfaceId,
              onEvent: (event) {},
            ),
          ),
        ),
      );

      expect(find.byType(Placeholder), findsOneWidget);
      expect(
        find.text('Widget with id: non_existent_root not found.'),
        findsOneWidget,
      );
    });
  });
}
