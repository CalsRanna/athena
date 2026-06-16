import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/service/chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';

typedef PermissionCallback = Future<bool> Function(String toolName, String description);

class AgentService {
  final ChatService _chatService;
  final ToolRegistry _toolRegistry;
  final SkillRegistry? _skillRegistry;

  AgentService({
    required ChatService chatService,
    required ToolRegistry toolRegistry,
    SkillRegistry? skillRegistry,
  })  : _chatService = chatService,
        _toolRegistry = toolRegistry,
        _skillRegistry = skillRegistry;

  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    ModelEntity? auxiliaryModel,
    ProviderEntity? auxiliaryModelProvider,
    CancelToken? cancelToken,
  }) async* {
    var messages = List<ChatMessage>.from(baseMessages);
    _skillRegistry?.clearContext();

    try {
      for (var iteration = 0; iteration < maxIterations; iteration++) {
      cancelToken?.throwIfCancelled();
      if (iteration == 0) {
        if (skillPrompt != null && skillPrompt.isNotEmpty) {
          messages = [
            ChatMessage.system(skillPrompt),
            ...messages,
          ];
        }
        if (evolutionPrompt != null && evolutionPrompt.isNotEmpty) {
          messages = [
            ChatMessage.system(evolutionPrompt),
            ...messages,
          ];
        }
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
        cancelToken?.throwIfCancelled();
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

        // Skill allowed-tools 白名单：命中则跳过弹窗
        final skillAllowed = tool != null &&
            (_skillRegistry?.isToolAllowed(tc.function.name) ?? false);

        // 持久化规则：命中则跳过弹窗
        final ruleMatched = permissionService?.check(tc.function.name, args) == true;

        if (!skillAllowed && !ruleMatched) {
          if (onPermission == null) {
            const deniedMsg =
                'Error: Tool requires user approval but no permission '
                'callback is configured.';
            yield AgentEvent.toolResult(
              id: tc.id,
              name: tc.function.name,
              result: deniedMsg,
            );
            messages.add(
                ChatMessage.tool(toolCallId: tc.id, content: deniedMsg));
            continue;
          }
          final approved = cancelToken == null
              ? await onPermission(tc.function.name, tc.function.arguments)
              : await Future.any<bool>([
                  onPermission(tc.function.name, tc.function.arguments),
                  cancelToken.whenCancelled.then((_) => false),
                ]);
          cancelToken?.throwIfCancelled();
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

        cancelToken?.throwIfCancelled();
        final result = tool != null
            ? await tool.execute(args)
            : 'Error: Unknown tool "${tc.function.name}"';

        var processedResult = smartTruncate(result);
        if (auxiliaryModel != null && auxiliaryModelProvider != null) {
          if (processedResult.length > 4000) {
            final summary = await _summarizeToolResult(
              toolName: tc.function.name,
              result: processedResult,
              auxModel: auxiliaryModel,
              auxProvider: auxiliaryModelProvider,
            );
            if (summary != null && summary.isNotEmpty) {
              processedResult = summary;
            }
          }
        }

        yield AgentEvent.toolResult(
          id: tc.id,
          name: tc.function.name,
          result: result,
        );

        messages.add(
            ChatMessage.tool(toolCallId: tc.id, content: processedResult));

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
    } finally {
      _skillRegistry?.clearContext();
    }
  }

  @visibleForTesting
  String smartTruncate(String result, {int threshold = 12000}) {
    if (result.length <= threshold) return result;
    final headLen = (threshold * 0.6).round();
    final tailLen = threshold - headLen;
    final head = result.substring(0, headLen);
    final tail = result.substring(result.length - tailLen);
    final skipped = result.length - headLen - tailLen;
    return '$head\n\n... [truncated $skipped characters] ...\n\n$tail';
  }

  Future<String?> _summarizeToolResult({
    required String toolName,
    required String result,
    required ModelEntity auxModel,
    required ProviderEntity auxProvider,
  }) async {
    try {
      final systemPrompt = _buildSummarizationPrompt(toolName);
      final messages = [
        ChatMessage.system(systemPrompt),
        ChatMessage.user(result),
      ];
      return await _chatService.complete(
        messages: messages,
        provider: auxProvider,
        model: auxModel,
      );
    } catch (_) {
      return null;
    }
  }

  String _buildSummarizationPrompt(String toolName) {
    const prefix =
        'You are a tool result summarizer. Extract the key information '
        'from the tool output below. Be concise but do not omit critical data '
        'like file paths, exit codes, error messages, URLs, or data values. '
        'Preserve exact numbers, identifiers, and code symbols.';
    final String toolSpecific = switch (toolName) {
      'bash' || 'powershell' =>
        'This is shell command output. Preserve: exit code, error messages, '
            'exact file paths. Summarize stdout/stderr, keeping any warnings or '
            'errors verbatim. Omit redundant or repetitive output lines.',
      'file_read' =>
        'This is file content. Preserve: code structure (function/class '
            'signatures), imports, key logic. Summarize the file\'s purpose and '
            'main components. Keep important code snippets intact.',
      'web_fetch' =>
        'This is fetched web page content. Extract: page title, main headings, '
            'key facts/data, and important links. Omit boilerplate, ads, '
            'navigation, and scripts.',
      'web_search' =>
        'This is web search results. Preserve: all result titles, URLs, and '
            'key snippets. Organize by relevance.',
      _ => 'Preserve all key information, data values, identifiers, and '
          'structural elements. Be thorough but concise.',
    };
    return '$prefix\n\n$toolSpecific';
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
