// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'genui_client.dart';
import 'genui_manager.dart';
import 'model/chat_message.dart';
import 'model/ui_models.dart';

const _maxConversationLength = 1000;

/// A high-level facade for the GenUI package.
///
/// This class provides a simple API for interacting with the GenUI client and
/// managing the UI state.
class UiAgent {
  /// Creates a new [UiAgent].
  ///
  /// If [genUiManager] or [client] are not provided, default instances are
  /// created.
  UiAgent({GenUiManager? genUiManager, GenUIClient? client})
    : _genUiManager = genUiManager ?? GenUiManager(),
      _client = client ?? GenUIClient();

  final GenUiManager _genUiManager;
  final GenUIClient _client;
  final _conversation = ValueNotifier<List<ChatMessage>>([]);

  void _addMessage(ChatMessage message) {
    _conversation.value.add(message);
    while (_conversation.value.length > _maxConversationLength) {
      _conversation.value.removeAt(0);
    }
    // Notify listeners
    _conversation.value = List.from(_conversation.value);
  }

  /// The surface builder for this agent.
  SurfaceBuilder get builder => _genUiManager;

  /// A stream of updates to the UI.
  Stream<GenUiUpdate> get updates => _genUiManager.updates;

  /// A list of messages in the conversation.
  ValueListenable<List<ChatMessage>> get conversation => _conversation;

  /// A [ValueListenable] that indicates whether the agent is currently
  /// processing a request.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  /// Returns a [ValueNotifier] for the given [surfaceId].
  ValueNotifier<UiDefinition?> surface(String surfaceId) {
    return _genUiManager.surface(surfaceId);
  }

  /// Sends a list of UI events to the GenUI server.
  Future<void> sendUiEvents(List<UiEvent> events) async {
    await sendRequest(UserMessage(events.map(UiEventPart.new).toList()));
  }

  /// Sends a request to the GenUI server to generate a UI.
  Future<void> sendRequest(UserMessage message) async {
    _addMessage(message);
    _isProcessing.value = true;
    try {
      await for (final chatMessage in _client.generateUI(
        _genUiManager.catalog,
        _conversation.value,
      )) {
        if (chatMessage is AiUiMessage) {
          _genUiManager.addOrUpdateSurface(
            chatMessage.surfaceId,
            chatMessage.definition,
          );
          // Check if a UI message for this surface already exists.
          final existingUiMessage = _conversation.value
              .whereType<AiUiMessage>()
              .firstWhereOrNull((m) => m.surfaceId == chatMessage.surfaceId);
          if (existingUiMessage == null) {
            _addMessage(chatMessage);
          }
        } else {
          _addMessage(chatMessage);
        }
      }
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Disposes of the resources used by this agent.
  void dispose() {
    _genUiManager.dispose();
  }
}
