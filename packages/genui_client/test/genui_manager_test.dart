// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';

void main() {
  group('GenUiManager', () {
    late GenUiManager manager;

    setUp(() {
      manager = GenUiManager();
    });

    test('constructor uses core catalog by default', () {
      expect(manager.catalog, coreCatalog);
      manager.dispose();
    });

    test('constructor uses provided catalog', () {
      const catalog = Catalog([]);
      final managerWithCatalog = GenUiManager(catalog: catalog);
      expect(managerWithCatalog.catalog, catalog);
      managerWithCatalog.dispose();
    });

    test(
      'surface() returns a notifier and creates one if it does not exist',
      () {
        final notifier = manager.surface('test_surface');
        expect(notifier, isNotNull);
        expect(manager.surfaces['test_surface'], notifier);
        final notifier2 = manager.surface('test_surface');
        expect(notifier2, same(notifier));
        manager.dispose();
      },
    );

    test('addOrUpdateSurface() adds a new surface and fires SurfaceAdded', () {
      const surfaceId = 'test_surface';
      final definition = {
        'root': 'root_widget',
        'widgets': [
          {
            'id': 'root_widget',
            'widget': {
              'Text': {'text': 'Hello'},
            },
          },
        ],
      };

      expectLater(
        manager.updates,
        emits(
          isA<SurfaceAdded>().having(
            (e) => e.surfaceId,
            'surfaceId',
            surfaceId,
          ),
        ),
      );

      manager.addOrUpdateSurface(surfaceId, definition);

      final notifier = manager.surface(surfaceId);
      expect(notifier.value, isNotNull);
      expect(notifier.value!.surfaceId, surfaceId);
      manager.dispose();
    });

    test(
      'addOrUpdateSurface() updates an existing surface and fires SurfaceUpdated',
      () {
        const surfaceId = 'test_surface';
        final definition1 = {'root': 'r1', 'widgets': []};
        final definition2 = {'root': 'r2', 'widgets': []};

        manager.addOrUpdateSurface(surfaceId, definition1);

        expectLater(
          manager.updates,
          emits(
            isA<SurfaceUpdated>().having(
              (e) => e.surfaceId,
              'surfaceId',
              surfaceId,
            ),
          ),
        );

        manager.addOrUpdateSurface(surfaceId, definition2);

        final notifier = manager.surface(surfaceId);
        expect(notifier.value, isNotNull);
        expect(notifier.value!.root, 'r2');
        manager.dispose();
      },
    );

    test('deleteSurface() removes a surface and fires SurfaceRemoved', () {
      const surfaceId = 'test_surface';
      final definition = {
        'root': 'root_widget',
        'widgets': [
          {
            'id': 'root_widget',
            'widget': {
              'Text': {'text': 'Hello'},
            },
          },
        ],
      };
      manager.addOrUpdateSurface(surfaceId, definition);

      expectLater(
        manager.updates,
        emits(
          isA<SurfaceRemoved>().having(
            (e) => e.surfaceId,
            'surfaceId',
            surfaceId,
          ),
        ),
      );

      manager.deleteSurface(surfaceId);

      expect(manager.surfaces.containsKey(surfaceId), isFalse);
      manager.dispose();
    });

    test('deleteSurface() does nothing for non-existent surface', () {
      expect(() => manager.deleteSurface('non_existent'), returnsNormally);
      manager.dispose();
    });

    test('dispose() disposes notifiers', () {
      final notifier = manager.surface('test_surface');
      manager.dispose();
      expect(() => notifier.addListener(() {}), throwsA(isA<FlutterError>()));
    });
  });
}
