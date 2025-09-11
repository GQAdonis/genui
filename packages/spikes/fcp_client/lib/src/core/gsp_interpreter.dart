// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/streaming_models.dart';

/// A client-side interpreter for the GenUI Streaming Protocol (GSP).
///
/// This class processes a stream of JSONL messages from a server, manages the
/// UI state, and builds a renderable layout. It notifies listeners when the UI
/// should be updated.
class GspInterpreter with ChangeNotifier {
  /// Creates a GspInterpreter that processes the given [stream] of JSONL
  /// messages.
  ///
  /// The [catalog] is used to validate the UI definition.
  GspInterpreter({required this.stream, required this.catalog}) {
    stream.listen(processMessage);
  }

  /// The input stream of raw JSONL strings from the server.
  final Stream<String> stream;

  /// The complete widget catalog for the application.
  final WidgetCatalog catalog;

  // Internal State
  final Map<String, LayoutNode> _nodeBuffer = <String, LayoutNode>{};
  Map<String, Object?> _state = <String, Object?>{};
  String? _rootId;
  bool _isReadyToRender = false;

  // Public Outputs

  /// The currently rendered layout, or `null` if the layout is not yet ready.
  Layout? get currentLayout {
    if (!isReadyToRender) {
      return null;
    }
    return Layout(root: _rootId!, nodes: _nodeBuffer.values.toList());
  }

  /// The current state of the UI.
  Map<String, Object?> get currentState => _state;

  /// Whether the interpreter has received enough information to render the UI.
  bool get isReadyToRender => _isReadyToRender;

  /// Processes a single JSONL message from the stream.
  void processMessage(String jsonlMessage) {
    if (jsonlMessage.isEmpty) {
      return;
    }
    final Map<String, Object?> jsonMap =
        json.decode(jsonlMessage) as Map<String, Object?>;
    final StreamMessage message = StreamMessage.fromMap(jsonMap);

    switch (message) {
      case StreamHeader():
        _handleStreamHeader(message);
        break;
      case LayoutMessage():
        _handleLayout(message);
        break;
      case LayoutRoot():
        _handleLayoutRoot(message);
        break;
      case StateUpdateMessage():
        _handleStateUpdate(message);
        break;
      case UnknownCatalogError():
        _handleUnknownCatalogError(message);
        break;
    }
  }

  void _handleStreamHeader(StreamHeader message) {
    _state = message.initialState;
    notifyListeners();
  }

  void _handleLayout(LayoutMessage message) {
    for (final LayoutNode node in message.nodes) {
      _nodeBuffer[node.id] = node;
    }
    if (_rootId != null && _nodeBuffer.containsKey(_rootId)) {
      _isReadyToRender = true;
    }
    notifyListeners();
  }

  void _handleLayoutRoot(LayoutRoot message) {
    _rootId = message.rootId;
    if (_nodeBuffer.containsKey(_rootId)) {
      _isReadyToRender = true;
      notifyListeners();
    }
  }

  void _handleStateUpdate(StateUpdateMessage message) {
    _state = _deepMerge(_state, message.state);
    notifyListeners();
  }

  Map<String, Object?> _deepMerge(
    Map<String, Object?> original,
    Map<String, Object?> update,
  ) {
    final Map<String, Object?> result = Map<String, Object?>.from(original);
    for (final String key in update.keys) {
      if (update[key] is Map<String, Object?> &&
          original[key] is Map<String, Object?>) {
        result[key] = _deepMerge(
          original[key] as Map<String, Object?>,
          update[key] as Map<String, Object?>,
        );
      } else {
        result[key] = update[key];
      }
    }
    return result;
  }

  void _handleUnknownCatalogError(UnknownCatalogError message) {
    // For now, just print the error. In a real application, you might
    // want to display an error to the user.
    debugPrint('Unknown catalog error: ${message.message}');
  }
}
