// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';
import 'package:genui_client/src/widgets/checkbox_group.dart';
import 'package:genui_client/src/widgets/column.dart';
import 'package:genui_client/src/widgets/elevated_button.dart';
import 'package:genui_client/src/widgets/image.dart';
import 'package:genui_client/src/widgets/radio_group.dart';
import 'package:genui_client/src/widgets/text.dart';
import 'package:genui_client/src/widgets/text_field.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  group('Catalog Widgets', () {
    UiEvent? lastEvent;
    void dispatchEvent(UiEvent event) {
      lastEvent = event;
    }

    setUp(() {
      lastEvent = null;
    });

    Widget buildTestWidget(CatalogItem item, Map<String, dynamic> data) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return item.widgetBuilder(
                data: data,
                id: 'test_widget',
                buildChild: (id) {
                  if (id == 'child_text') {
                    return const Text('Child Text');
                  }
                  return const SizedBox();
                },
                dispatchEvent: dispatchEvent,
                context: context,
                values: {},
              );
            },
          ),
        ),
      );
    }

    testWidgets('ElevatedButton', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(elevatedButton, {'child': 'child_text'}),
      );

      expect(find.text('Child Text'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));

      expect(lastEvent, isNotNull);
      expect(lastEvent!.widgetId, 'test_widget');
      expect(lastEvent!.eventType, 'onTap');
      expect(lastEvent!.isAction, isTrue);
    });

    testWidgets('Column', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(column, {
          'children': ['child_text', 'child_text'],
          'spacing': 16.0,
          'mainAxisAlignment': 'center',
          'crossAxisAlignment': 'end',
        }),
      );

      expect(find.text('Child Text'), findsNWidgets(2));
      final columnWidget = tester.widget<Column>(find.byType(Column));
      expect(columnWidget.mainAxisAlignment, MainAxisAlignment.center);
      expect(columnWidget.crossAxisAlignment, CrossAxisAlignment.end);
    });

    testWidgets('Column with default values', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(column, {
          'children': ['child_text'],
        }),
      );

      final columnWidget = tester.widget<Column>(find.byType(Column));
      expect(columnWidget.mainAxisAlignment, MainAxisAlignment.start);
      expect(columnWidget.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets('Text', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(text, {'text': 'Hello World'}));

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('CheckboxGroup', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(checkboxGroup, {
          'values': [true, false],
          'labels': ['Option 1', 'Option 2'],
        }),
      );

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      await tester.tap(find.text('Option 2'));
      await tester.pump();

      expect(lastEvent, isNotNull);
      expect(lastEvent!.widgetId, 'test_widget');
      expect(lastEvent!.eventType, 'onChanged');
      expect(lastEvent!.isAction, isFalse);
      expect(lastEvent!.value, [true, true]);
    });

    testWidgets('RadioGroup', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(radioGroup, {
          'groupValue': 'Option 1',
          'labels': ['Option 1', 'Option 2'],
        }),
      );

      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      await tester.tap(find.text('Option 2'));
      await tester.pump();

      expect(lastEvent, isNotNull);
      expect(lastEvent!.widgetId, 'test_widget');
      expect(lastEvent!.eventType, 'onChanged');
      expect(lastEvent!.isAction, isFalse);
      expect(lastEvent!.value, 'Option 2');
    });

    testWidgets('TextField onChanged', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(textField, {
          'value': 'initial',
          'hintText': 'hint',
          'obscureText': true,
        }),
      );

      final textFieldWidget = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldWidget.controller!.text, 'initial');
      expect(textFieldWidget.decoration!.hintText, 'hint');
      expect(textFieldWidget.obscureText, isTrue);

      await tester.enterText(find.byType(TextField), 'new value');

      expect(lastEvent, isNotNull);
      expect(lastEvent!.widgetId, 'test_widget');
      expect(lastEvent!.eventType, 'onChanged');
      expect(lastEvent!.isAction, isFalse);
      expect(lastEvent!.value, 'new value');
    });

    testWidgets('TextField onSubmitted', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(textField, {'value': 'initial'}));

      await tester.enterText(find.byType(TextField), 'submitted');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(lastEvent, isNotNull);
      expect(lastEvent!.widgetId, 'test_widget');
      expect(lastEvent!.eventType, 'onSubmitted');
      expect(lastEvent!.isAction, isTrue);
      expect(lastEvent!.value, 'submitted');
    });

    testWidgets('Image from network', (WidgetTester tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          buildTestWidget(image, {'url': 'https://example.com/image.png'}),
        );
        expect(find.byType(Image), findsOneWidget);
        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.image, isA<NetworkImage>());
      });
    });

    testWidgets('Image from asset', (WidgetTester tester) async {
      // This will fail without a real asset, but we can check the type.
      // To make it pass, we would need to provide a dummy asset.
      await tester.pumpWidget(
        buildTestWidget(image, {'assetName': 'assets/test.png'}),
      );
      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<AssetImage>());
    });

    testWidgets('Image throws if both url and assetName are provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(image, {'url': 'url', 'assetName': 'asset'}),
      );
      expect(tester.takeException(), isA<Exception>());
    });

    testWidgets('Image throws if neither url nor assetName are provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(image, {}));
      expect(tester.takeException(), isA<Exception>());
    });
  });
}
