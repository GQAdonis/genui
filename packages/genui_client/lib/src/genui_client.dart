// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../genui_client.dart';

class GenUIClient {
  final String _baseUrl;
  final http.Client _client;

  GenUIClient({String baseUrl = 'http://localhost:3400'})
    : _baseUrl = baseUrl,
      _client = http.Client();

  @visibleForTesting
  GenUIClient.withClient(
    http.Client client, {
    String baseUrl = 'http://localhost:3400',
  }) : _baseUrl = baseUrl,
       _client = client;

  /// Generates a UI by sending the current conversation to the GenUI server.
  ///
  /// This method returns a stream of [ChatMessage]s. These can be either
  /// [AiUiMessage]s containing UI definitions as they are generated, or a final
  /// [AiTextMessage] from the model.
  Stream<ChatMessage> generateUI(
    Catalog catalog,
    List<ChatMessage> conversation,
  ) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/generateUi?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';

    Object? toEncodable(Object? object) {
      if (object is Schema) {
        return object.toJson();
      }
      return object;
    }

    request.body = jsonEncode({
      'data': {
        'catalog': catalog.schema,
        'conversation': conversation.map((m) => m.toJson()).toList(),
      },
    }, toEncodable: toEncodable);

    final response = await _client.send(request);

    if (response.statusCode == 200) {
      await for (final chunk in response.stream) {
        final decoded = utf8.decode(chunk);
        // Genkit streams can sometimes send multiple JSON objects
        for (var line in decoded.split('\n').where((s) => s.isNotEmpty)) {
          genUiLogger.fine('Received chunk from server: $line');
          if (line.startsWith('data: ')) {
            line = line.substring(6);
          }
          final json = jsonDecode(line) as Map<String, Object?>;

          final isFinal = json.containsKey('result');
          final message = isFinal
              ? (json['result'] as Map<String, Object?>)['message']
                    as Map<String, Object?>?
              : json['message'] as Map<String, Object?>?;

          if (message == null) continue;

          if (message.containsKey('content')) {
            final content = message['content'] as List<Object?>;

            if (isFinal) {
              // It's the final message, aggregate text parts.
              final text = content
                  .whereType<Map<String, Object?>>()
                  .where((part) => part.containsKey('text'))
                  .map((part) => part['text'] as String)
                  .join('');
              if (text.isNotEmpty) {
                yield AiTextMessage.text(text);
              }
            } else {
              // It's a streaming chunk, only process tool requests.
              for (final part in content) {
                final partMap = part as Map<String, Object?>;
                if (partMap.containsKey('toolRequest')) {
                  final toolRequest =
                      partMap['toolRequest'] as Map<String, Object?>;
                  final toolName = toolRequest['name'] as String;
                  if (toolName == 'addOrUpdateSurface') {
                    final input = toolRequest['input'] as Map<String, Object?>;
                    final definition =
                        input['definition'] as Map<String, Object?>;
                    final surfaceId = input['surfaceId'] as String;
                    yield AiUiMessage(
                      definition: definition,
                      surfaceId: surfaceId,
                    );
                  }
                  // TODO: Handle deleteSurface
                }
              }
            }
          }
        }
      }
    } else {
      throw Exception(
        'Failed to generate UI: ${await response.stream.bytesToString()}',
      );
    }
  }
}
