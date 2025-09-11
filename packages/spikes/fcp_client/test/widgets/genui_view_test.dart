// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:fcp_client/fcp_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenUiView', () {
    late StreamController<String> streamController;
    late GspInterpreter interpreter;
    late WidgetCatalogRegistry registry;

    setUp(() {
      streamController = StreamController<String>();
      registry = WidgetCatalogRegistry();
      registry.register(
        CatalogItem(
          name: 'Text',
          builder: (context, node, properties, children) =>
              Text(properties['data'] as String? ?? ''),
          definition: WidgetDefinition(
            properties: ObjectSchema(
              properties: {
                'data': Schema.string(),
              },
            ),
          ),
        ),
      );
      registry.register(
        CatalogItem(
          name: 'Column',
          builder: (context, node, properties, children) => Column(
            children: children['children'] ?? [],
          ),
          definition: WidgetDefinition(
            properties: ObjectSchema(
              properties: {
                'children': Schema.list(items: Schema.string()),
              },
            ),
          ),
        ),
      );
      interpreter = GspInterpreter(
        stream: streamController.stream,
        catalog: registry.buildCatalog(),
      );
    });

    testWidgets('shows loading indicator until ready',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders UI when ready', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "Hello"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('displays error for cyclical layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["child1"]}}, {"id": "child1", "type": "Column", "properties": {"children": ["root"]}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.textContaining('Cyclical layout detected'), findsOneWidget);
    });

    testWidgets('displays error for missing builder',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "MissingWidget"}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(
          find.textContaining('No builder registered for widget type'),
          findsOneWidget);
    });

    testWidgets('resolves string interpolation binding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"name": "World"}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "Hello, \${name}!"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Hello, World!'), findsOneWidget);
    });

    testWidgets('resolves \$bind map binding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"name": "World"}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": {"\$bind": "name"}}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('updates layout by adding a widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["child1"]}}, {"id": "child1", "type": "Text", "properties": {"data": "Child 1"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsNothing);

      // Now add a child to the column.
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["child1", "child2"]}}, {"id": "child2", "type": "Text", "properties": {"data": "Child 2"}}]}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
    });

    testWidgets('updates layout by removing a widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["child1", "child2"]}}, {"id": "child1", "type": "Text", "properties": {"data": "Child 1"}}, {"id": "child2", "type": "Text", "properties": {"data": "Child 2"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);

      // Now remove child2 from the column.
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["child1"]}}]}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsNothing);
    });

    testWidgets('updates UI on state update', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"name": "Initial"}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": {"\$bind": "name"}}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Initial'), findsOneWidget);

      // Now update the state.
      streamController.add(
        '{"messageType": "StateUpdate", "state": {"name": "Updated"}}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Updated'), findsOneWidget);
    });
    testWidgets('updates widget properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "Initial Text"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Initial Text'), findsOneWidget);

      // Now update the properties of the same widget.
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "Updated Text"}}]}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Updated Text'), findsOneWidget);
    });

    testWidgets('re-parents a widget', (WidgetTester tester) async {
      registry.register(
        CatalogItem(
          name: 'Column',
          builder: (context, node, properties, children) => Column(
            key: Key(node.id),
            children: children['children'] ?? [],
          ),
          definition: WidgetDefinition(
            properties: ObjectSchema(
              properties: {
                'children': Schema.list(items: Schema.string()),
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiView(interpreter: interpreter, registry: registry),
          ),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["col1", "col2"]}}, {"id": "col1", "type": "Column", "properties": {"children": ["movable_text"]}}, {"id": "col2", "type": "Column", "properties": {}}, {"id": "movable_text", "type": "Text", "properties": {"data": "Movable"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byKey(const Key('col1')),
              matching: find.text('Movable')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('col2')),
              matching: find.text('Movable')),
          findsNothing);

      // Now move the text to the second column.
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "col1", "type": "Column", "properties": {}}, {"id": "col2", "type": "Column", "properties": {"children": ["movable_text"]}}]}',
      );
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byKey(const Key('col1')),
              matching: find.text('Movable')),
          findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const Key('col2')),
              matching: find.text('Movable')),
          findsOneWidget);
    });

    testWidgets('reorders children in a list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["text_a", "text_b"]}}, {"id": "text_a", "type": "Text", "properties": {"data": "A"}}, {"id": "text_b", "type": "Text", "properties": {"data": "B"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      final firstText = tester.widget<Text>(find.byType(Text).at(0));
      expect(firstText.data, 'A');

      // Now reorder the children.
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["text_b", "text_a"]}}]}',
      );
      await tester.pumpAndSettle();

      final newFirstText = tester.widget<Text>(find.byType(Text).at(0));
      expect(newFirstText.data, 'B');
    });

    testWidgets('handles deeply nested state updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"user": {"name": "Alice", "address": {"city": "Initial City"}}}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "\${user.address.city}"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Initial City'), findsOneWidget);

      // Now update a nested property.
      streamController.add(
        '{"messageType": "StateUpdate", "state": {"user": {"address": {"city": "Updated City"}}}}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Updated City'), findsOneWidget);
      expect(interpreter.currentState['user'],
          isA<Map>().having((m) => m['name'], 'name', 'Alice'));
    });

    testWidgets('handles state value becoming null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenUiView(interpreter: interpreter, registry: registry),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"name": "Alice"}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "Text", "properties": {"data": "\${name}"}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);

      // Now set the state value to null.
      streamController.add(
        '{"messageType": "StateUpdate", "state": {"name": null}}',
      );
      await tester.pumpAndSettle();

      expect(find.text(''), findsOneWidget);
    });
  });
}
