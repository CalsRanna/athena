import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/tool/tool_interface.dart' show DangerLevel;
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/service/chat_service.dart';
import 'package:openai_dart/openai_dart.dart';

typedef PermissionCallback = Future<bool> Function(String toolName, String description);

class AgentService {
  final ChatService _chatService;
  final ToolRegistry _toolRegistry;

  AgentService({
    ChatService? chatService,
    ToolRegistry? toolRegistry,
  })  : _chatService = chatService ?? ChatService(),
        _toolRegistry = toolRegistry ?? ToolRegistry();

  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    PermissionCallback? onPermission,
    int maxIterations = 100,
  }) async* {
    var messages = List<ChatMessage>.from(baseMessages);

    for (var iteration = 0; iteration < maxIterations; iteration++) {
      if (iteration == 0 && skillPrompt != null && skillPrompt.isNotEmpty) {
        messages = [
          ChatMessage.system(skillPrompt),
          ...messages,
        ];
      }

      final toolDefs = _toolRegistry.definitions;
      final request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: messages,
        tools: toolDefs.isNotEmpty
            ? toolDefs.map((t) => Tool.function(
                  name: t['function']['name'] as String,
                  description: t['function']['description'] as String,
                  parameters: t['function']['parameters']
                      as Map<String, dynamic>,
                )).toList()
            : null,
      );

      final stream = _chatService.getCompletion(
        chat: chat,
        messages: messages,
        provider: provider,
        model: model,
        tools: request.tools,
      );

      final accumulator = ChatStreamAccumulator();

      await for (final chunk in stream) {
        accumulator.add(chunk);

        final delta = chunk.firstChoice?.delta;
        if (delta != null) {
          final reasoningContent =
              delta.reasoningContent ?? delta.reasoning;
          if (reasoningContent != null && reasoningContent.isNotEmpty) {
            yield AgentEvent.reasoning(reasoningContent);
          }
        }

        final textDelta = chunk.textDelta;
        if (textDelta != null && textDelta.isNotEmpty) {
          yield AgentEvent.text(textDelta);
        }
      }

      final toolCalls = accumulator.toolCalls;

      if (toolCalls.isEmpty) {
        yield AgentEvent.done(content: accumulator.content);
        return;
      }

      final toolCallDataList = <Map<String, dynamic>>[];
      for (final tc in toolCalls) {
        yield AgentEvent.toolCall(
          id: tc.id,
          name: tc.function.name,
          arguments: tc.function.arguments,
        );
      }

      messages.add(ChatMessage.assistant(
        content: accumulator.content.isNotEmpty ? accumulator.content : null,
        toolCalls: toolCalls,
      ));

      for (final tc in toolCalls) {
        Map<String, dynamic> args;
        try {
          args = jsonDecode(tc.function.arguments) as Map<String, dynamic>;
        } catch (_) {
          args = {};
        }

        final tool = _toolRegistry.get(tc.function.name);

        if (onPermission != null &&
            tool != null &&
            tool.dangerLevel == DangerLevel.needsApproval) {
          final approved =
              await onPermission(tc.function.name, tc.function.arguments);
          if (!approved) {
            const deniedMsg = 'User denied the tool execution.';
            yield AgentEvent.toolResult(
              id: tc.id,
              name: tc.function.name,
              result: deniedMsg,
            );
            messages.add(ChatMessage.tool(
                toolCallId: tc.id, content: deniedMsg));
            continue;
          }
        }

        final result = tool != null
            ? await tool.execute(args)
            : 'Error: Unknown tool "${tc.function.name}"';

        yield AgentEvent.toolResult(
          id: tc.id,
          name: tc.function.name,
          result: result,
        );

        messages.add(ChatMessage.tool(toolCallId: tc.id, content: result));

        toolCallDataList.add({
          'id': tc.id,
          'name': tc.function.name,
          'arguments': tc.function.arguments,
          'result': result,
        });
      }

      yield AgentEvent.iterationComplete(
        toolCalls: toolCallDataList,
        content: accumulator.content,
      );
    }
  }
}

sealed class AgentEvent {
  const AgentEvent();

  const factory AgentEvent.text(String delta) = AgentTextEvent;

  const factory AgentEvent.reasoning(String delta) = AgentReasoningEvent;

  const factory AgentEvent.toolCall({
    required String id,
    required String name,
    required String arguments,
  }) = AgentToolCallEvent;

  const factory AgentEvent.toolResult({
    required String id,
    required String name,
    required String result,
  }) = AgentToolResultEvent;

  const factory AgentEvent.iterationComplete({
    required List<Map<String, dynamic>> toolCalls,
    required String content,
  }) = AgentIterationCompleteEvent;

  const factory AgentEvent.done({required String content}) = AgentDoneEvent;
}

class AgentTextEvent extends AgentEvent {
  final String delta;
  const AgentTextEvent(this.delta);
}

class AgentReasoningEvent extends AgentEvent {
  final String delta;
  const AgentReasoningEvent(this.delta);
}

class AgentToolCallEvent extends AgentEvent {
  final String id;
  final String name;
  final String arguments;
  const AgentToolCallEvent({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class AgentToolResultEvent extends AgentEvent {
  final String id;
  final String name;
  final String result;
  const AgentToolResultEvent({
    required this.id,
    required this.name,
    required this.result,
  });
}

class AgentIterationCompleteEvent extends AgentEvent {
  final List<Map<String, dynamic>> toolCalls;
  final String content;
  const AgentIterationCompleteEvent({
    required this.toolCalls,
    required this.content,
  });
}

class AgentDoneEvent extends AgentEvent {
  final String content;
  const AgentDoneEvent({required this.content});
}
