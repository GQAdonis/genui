// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GenUIClient', () {
    test('generateUI succeeds with UI messages', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        expect(
          request.url.toString(),
          'http://localhost:3400/generateUi?stream=true',
        );
        expect(request.method, 'POST');
        final body =
            jsonDecode(await bodyStream.bytesToString())
                as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        expect(data['catalog'], isA<Map<String, dynamic>>());
        expect(data['conversation'], isA<List<dynamic>>());

        final stream = Stream.fromIterable([
          utf8.encode(
            'data: ${jsonEncode({
              'message': {
                'content': [
                  {
                    'toolRequest': {
                      'name': 'addOrUpdateSurface',
                      'input': {
                        'surfaceId': 'surface1',
                        'definition': {'root': 'root1', 'widgets': <Map<String, Object?>>[]},
                      },
                    },
                  },
                ],
              },
            })}\n',
          ),
          utf8.encode(
            jsonEncode({
              'message': {
                'content': [
                  {
                    'toolRequest': {
                      'name': 'addOrUpdateSurface',
                      'input': {
                        'surfaceId': 'surface2',
                        'definition': {
                          'root': 'root2',
                          'widgets': <Map<String, Object?>>[],
                        },
                      },
                    },
                  },
                ],
              },
            }),
          ),
        ]);
        return http.StreamedResponse(stream, 200);
      });

      final client = GenUIClient.withClient(mockClient);
      final stream = client.generateUI(const Catalog([]), []);

      final definitions = await stream.toList();

      expect(definitions.length, 2);
      final uiMessage1 = definitions[0] as AiUiMessage;
      expect(uiMessage1.surfaceId, 'surface1');
      expect(uiMessage1.definition['root'], 'root1');
      final uiMessage2 = definitions[1] as AiUiMessage;
      expect(uiMessage2.surfaceId, 'surface2');
      expect(uiMessage2.definition['root'], 'root2');
    });

    test('generateUI succeeds with final text message', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final stream = Stream.fromIterable([
          utf8.encode(
            jsonEncode({
              'result': {
                'message': {
                  'content': [
                    {'text': 'Hello '},
                    {'text': 'World'},
                  ],
                },
              },
            }),
          ),
        ]);
        return http.StreamedResponse(stream, 200);
      });

      final client = GenUIClient.withClient(mockClient);
      final stream = client.generateUI(const Catalog([]), []);

      final messages = await stream.toList();

      expect(messages.length, 1);
      final textMessage = messages[0] as AiTextMessage;
      final text = textMessage.parts
          .whereType<TextPart>()
          .map((p) => p.text)
          .join('');
      expect(text, 'Hello World');
    });

    test('generateUI handles empty stream', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      final client = GenUIClient.withClient(mockClient);
      final stream = client.generateUI(const Catalog([]), []);

      final messages = await stream.toList();
      expect(messages, isEmpty);
    });

    test('generateUI handles malformed JSON', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(Stream.value(utf8.encode('{')), 200);
      });

      final client = GenUIClient.withClient(mockClient);
      final stream = client.generateUI(const Catalog([]), []);

      expect(stream.toList, throwsA(isA<FormatException>()));
    });

    test('generateUI fails', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('Server error')),
          500,
        );
      });

      final client = GenUIClient.withClient(mockClient);
      final stream = client.generateUI(const Catalog([]), []);

      expect(
        stream.toList,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString()',
            'Exception: Failed to generate UI: Server error',
          ),
        ),
      );
    });
  });
}
