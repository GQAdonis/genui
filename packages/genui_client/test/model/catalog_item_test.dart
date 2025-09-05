// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';

void main() {
  group('WidgetValueStore', () {
    late WidgetValueStore valueStore;

    setUp(() {
      valueStore = WidgetValueStore();
    });

    test('forSurface returns a new map for a new surfaceId', () {
      final surfaceValues = valueStore.forSurface('surface1');
      expect(surfaceValues, isA<Map<String, Object?>>());
      expect(surfaceValues, isEmpty);
    });

    test('forSurface returns the same map for the same surfaceId', () {
      final surfaceValues1 = valueStore.forSurface('surface1');
      final surfaceValues2 = valueStore.forSurface('surface1');
      expect(surfaceValues1, same(surfaceValues2));
    });

    test('forSurface returns different maps for different surfaceIds', () {
      final surfaceValues1 = valueStore.forSurface('surface1');
      final surfaceValues2 = valueStore.forSurface('surface2');
      expect(surfaceValues1, isNot(same(surfaceValues2)));
    });

    test('delete removes the value store for a surfaceId', () {
      final originalValues = valueStore.forSurface('surface1');
      originalValues['key'] = 'value';
      valueStore.delete('surface1');
      final newValues = valueStore.forSurface('surface1');
      expect(newValues, isEmpty);
    });

    test('delete does not throw for non-existent surfaceId', () {
      expect(() => valueStore.delete('non-existent'), returnsNormally);
    });
  });
}
