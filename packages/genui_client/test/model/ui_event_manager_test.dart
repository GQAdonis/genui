// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client_core.dart';

void main() {
  group('UiEventManager', () {
    test('coalesces change events', () {
      final sentEvents = <UiEvent>[];
      final manager = UiEventManager(
        callback: (surfaceId, events) {
          sentEvents.addAll(events);
        },
      );

      final event1 = UiChangeEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onChange',
        value: 'a',
      );
      final event2 = UiChangeEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onChange',
        value: 'b',
      );
      final actionEvent = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w2',
        eventType: 'onTap',
      );

      manager.add(event1);
      manager.add(event2);
      manager.add(actionEvent);

      expect(sentEvents.length, 2);
      expect(sentEvents.contains(actionEvent), isTrue);
      expect(sentEvents.contains(event2), isTrue);
      expect(sentEvents.contains(event1), isFalse); // Coalesced
    });

    test('sends action events immediately', () {
      final sentEvents = <UiEvent>[];
      final manager = UiEventManager(
        callback: (surfaceId, events) {
          sentEvents.addAll(events);
        },
      );

      final actionEvent = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onTap',
      );
      final actionEvent2 = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w2',
        eventType: 'onTap',
      );

      manager.add(actionEvent);
      expect(sentEvents.length, 1);
      expect(sentEvents.first, actionEvent);

      manager.add(actionEvent2);
      expect(sentEvents.length, 2);
      expect(sentEvents.last, actionEvent2);
    });

    test('sends action event with no prior change events', () {
      final sentEvents = <UiEvent>[];
      final manager = UiEventManager(
        callback: (surfaceId, events) {
          sentEvents.addAll(events);
        },
      );

      final actionEvent = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onTap',
      );

      manager.add(actionEvent);

      expect(sentEvents.length, 1);
      expect(sentEvents.first, actionEvent);
    });

    test('keeps events from different surfaces separate', () {
      final surface1Events = <UiEvent>[];
      final surface2Events = <UiEvent>[];
      final manager = UiEventManager(
        callback: (surfaceId, events) {
          if (surfaceId == 's1') {
            surface1Events.addAll(events);
          } else if (surfaceId == 's2') {
            surface2Events.addAll(events);
          }
        },
      );

      final event1 = UiChangeEvent(
        surfaceId: 's1',
        widgetId: 'w1',
        eventType: 'onChange',
        value: 'a',
      );
      final event2 = UiChangeEvent(
        surfaceId: 's2',
        widgetId: 'w1',
        eventType: 'onChange',
        value: 'b',
      );
      final actionEvent = UiActionEvent(
        surfaceId: 's1',
        widgetId: 'w2',
        eventType: 'onTap',
      );

      manager.add(event1);
      manager.add(event2);
      manager.add(actionEvent);

      expect(surface1Events.length, 2);
      expect(surface1Events.contains(actionEvent), isTrue);
      expect(surface1Events.contains(event1), isTrue);

      expect(surface2Events.isEmpty, isTrue);

      final actionEvent2 = UiActionEvent(
        surfaceId: 's2',
        widgetId: 'w2',
        eventType: 'onTap',
      );
      manager.add(actionEvent2);
      expect(surface2Events.length, 2);
      expect(surface2Events.contains(actionEvent2), isTrue);
      expect(surface2Events.contains(event2), isTrue);
    });
  });
}
