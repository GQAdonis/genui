// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:fcp_client/fcp_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenUiView ListViewBuilder', () {
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
      registry.register(
        CatalogItem(
          name: 'ListItem',
          builder: (context, node, properties, children) => ListTile(
            title: Text(properties['text'] as String? ?? ''),
          ),
          definition: WidgetDefinition(
            properties: ObjectSchema(
              properties: {
                'text': Schema.string(),
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

    testWidgets('renders a list of items from state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiView(interpreter: interpreter, registry: registry),
          ),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"items": [{"text": "Item 1"}, {"text": "Item 2"}]}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "ListViewBuilder", "properties": {"data": {"\$bind": "items"}}, "itemTemplate": {"id": "template", "type": "ListItem", "properties": {"text": {"\$bind": "item.text"}}}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('updates the list when state changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiView(interpreter: interpreter, registry: registry),
          ),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"items": [{"text": "Item 1"}]}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "ListViewBuilder", "properties": {"data": {"\$bind": "items"}}, "itemTemplate": {"id": "template", "type": "ListItem", "properties": {"text": {"\$bind": "item.text"}}}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsNothing);

      streamController.add(
        '{"messageType": "StateUpdate", "state": {"items": [{"text": "Item 1"}, {"text": "Item 2"}]}}',
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('displays error if itemTemplate is missing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiView(interpreter: interpreter, registry: registry),
          ),
        ),
      );

      streamController.add(
        '{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"items": []}}',
      );
      streamController.add(
        '{"messageType": "Layout", "nodes": [{"id": "root", "type": "ListViewBuilder", "properties": {"data": {"\$bind": "items"}}}]}',
      );
      streamController.add('{"messageType": "LayoutRoot", "rootId": "root"}');
      await tester.pumpAndSettle();

      expect(find.textContaining('is missing itemTemplate'), findsOneWidget);
    });
  });
}
