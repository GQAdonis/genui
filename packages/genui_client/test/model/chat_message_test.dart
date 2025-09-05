// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_client/genui_client.dart';
import 'package:genui_client/genui_client_core.dart';

void main() {
  group('ChatMessage and MessagePart', () {
    group('TextPart', () {
      test('toJson works correctly', () {
        const part = TextPart('hello');
        expect(part.toJson(), {'type': 'text', 'text': 'hello'});
      });
    });

    group('UiEventPart', () {
      test('toJson works correctly', () {
        final event = UiActionEvent(widgetId: 'w1', eventType: 'onTap');
        final part = UiEventPart(event);
        expect(part.toJson(), {'type': 'uiEvent', 'event': event.toMap()});
      });
    });

    group('ImagePart', () {
      test('fromBytes toJson works correctly', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final part = ImagePart.fromBytes(bytes, mimeType: 'image/png');
        expect(part.toJson(), {
          'type': 'image',
          'base64': base64Encode(bytes),
          'mimeType': 'image/png',
        });
      });

      test('fromBase64 toJson works correctly', () {
        const base64 = 'AQID';
        const part = ImagePart.fromBase64(base64, mimeType: 'image/png');
        expect(part.toJson(), {
          'type': 'image',
          'base64': base64,
          'mimeType': 'image/png',
        });
      });

      test('fromUrl toJson works correctly', () {
        final url = Uri.parse('https://example.com/image.png');
        final part = ImagePart.fromUrl(url);
        expect(part.toJson(), {'type': 'image', 'url': url.toString()});
      });
    });

    group('UserMessage', () {
      test('text factory works', () {
        final message = UserMessage.text('hello');
        expect(message.parts.length, 1);
        expect(message.parts.first, isA<TextPart>());
        expect((message.parts.first as TextPart).text, 'hello');
      });

      test('fromEvent factory works', () {
        final event = UiActionEvent(widgetId: 'w1', eventType: 'onTap');
        final message = UserMessage.fromEvent(event);
        expect(message.parts.length, 1);
        expect(message.parts.first, isA<UiEventPart>());
        expect((message.parts.first as UiEventPart).event, event);
      });

      test('toJson works correctly', () {
        final message = const UserMessage([TextPart('hello')]);
        expect(message.toJson(), {
          'role': 'user',
          'parts': [
            {'type': 'text', 'text': 'hello'},
          ],
        });
      });
    });

    group('AiTextMessage', () {
      test('text factory works', () {
        final message = AiTextMessage.text('hello');
        expect(message.parts.length, 1);
        expect(message.parts.first, isA<TextPart>());
        expect((message.parts.first as TextPart).text, 'hello');
      });

      test('toJson works correctly', () {
        final message = const AiTextMessage([TextPart('hello')]);
        expect(message.toJson(), {
          'role': 'model',
          'parts': [
            {'type': 'text', 'text': 'hello'},
          ],
        });
      });
    });

    group('AiUiMessage', () {
      test('constructor generates surfaceId if not provided', () {
        final message = AiUiMessage(definition: const {});
        expect(message.surfaceId, isNotNull);
      });

      test('constructor uses provided surfaceId', () {
        final message = AiUiMessage(definition: const {}, surfaceId: 's1');
        expect(message.surfaceId, 's1');
      });

      test('toJson works correctly', () {
        final definition = {'root': 'r1'};
        final message = AiUiMessage(definition: definition, surfaceId: 's1');
        expect(message.toJson(), {
          'role': 'model',
          'parts': [
            {
              'type': 'ui',
              'definition': {'surfaceId': 's1', ...definition},
            },
          ],
        });
      });
    });

    group('InternalMessage', () {
      test('toJson returns empty map', () {
        const message = InternalMessage('internal');
        expect(message.toJson(), isEmpty);
      });
    });

    group('ToolResponseMessage', () {
      test('toJson returns empty map', () {
        const message = ToolResponseMessage([]);
        expect(message.toJson(), isEmpty);
      });
    });

    group('ToolResultPart', () {
      test('toJson works correctly', () {
        const part = ToolResultPart(callId: 'c1', result: 'res1');
        expect(part.toJson(), {'callId': 'c1', 'result': 'res1'});
      });
    });
  });
}
