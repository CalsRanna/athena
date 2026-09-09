import 'dart:convert';
import 'dart:math';

import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:openai_dart/openai_dart.dart';

/// Checks every request, including iterations within a single run.
/// Token estimates are conservative heuristics, calibrated upward by API usage.
class ContextBudget {
  ContextBudget(this.contextWindow);

  final int contextWindow;
  double _usageScale = 1;

  int get inputLimit => contextWindow - min(8192, max(256, contextWindow ~/ 5));

  int estimate(List<ChatMessage> messages, List<Tool>? tools) =>
      (_estimate(messages, tools) * _usageScale).ceil();

  void observe({
    required int promptTokens,
    required List<ChatMessage> messages,
    required List<Tool>? tools,
  }) {
    final estimated = _estimate(messages, tools);
    if (estimated > 0) {
      _usageScale = max(_usageScale, promptTokens / estimated);
    }
  }

  Future<List<ChatMessage>> prepare({
    required List<ChatMessage> messages,
    required List<Tool>? tools,
    required ToolOutputStore outputs,
  }) async {
    final requestMessages = List<ChatMessage>.of(messages);
    if (contextWindow <= 0 || estimate(requestMessages, tools) <= inputLimit) {
      return requestMessages;
    }

    // Keep the newest tool batch intact, especially a page just read on demand.
    // Older results remain recoverable; assistant/tool pairing is never changed.
    final latestBatch = messages.lastIndexWhere(
      (m) => m is AssistantMessage && (m.toolCalls?.isNotEmpty ?? false),
    );
    final end = latestBatch < 0 ? messages.length : latestBatch;
    for (var i = 0; i < end; i++) {
      final message = requestMessages[i];
      if (message is! ToolMessage || message.content.length <= 512) continue;
      requestMessages[i] = ChatMessage.tool(
        toolCallId: message.toolCallId,
        content: await outputs.reference(message.content),
      );
      if (estimate(requestMessages, tools) <= inputLimit) {
        return requestMessages;
      }
    }

    throw StateError(
      'Context budget exceeded: approximately '
      '${estimate(requestMessages, tools)} input tokens, '
      '$inputLimit available in a $contextWindow-token window '
      '(output space reserved). Reduce the conversation context or use '
      'a model with a larger context window. Saved tool outputs are retained.',
    );
  }

  int _estimate(List<ChatMessage> messages, List<Tool>? tools) {
    var imageTokens = 0;
    Object? withoutImageData(Object? value) {
      if (value is Map) {
        return <String, Object?>{
          for (final entry in value.entries)
            entry.key as String: entry.key == 'image_url'
                ? (() {
                    imageTokens += 4096;
                    return '[image]';
                  })()
                : withoutImageData(entry.value),
        };
      }
      if (value is List) return value.map(withoutImageData).toList();
      return value;
    }

    final payload = withoutImageData({
      'messages': messages.map((m) => m.toJson()).toList(),
      if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
    });
    // Two UTF-8 bytes per token deliberately leaves room for code/non-Latin text.
    // Providers can tokenize differently; observed usage corrects underestimates.
    return (utf8.encode(jsonEncode(payload)).length / 2).ceil() +
        messages.length * 16 +
        imageTokens;
  }
}
