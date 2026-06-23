import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/model/token_usage.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/util/logger_util.dart';
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
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    ModelEntity? auxiliaryModel,
    ProviderEntity? auxiliaryModelProvider,
    CancelToken? cancelToken,
  }) async* {
    var messages = _injectPrompts(baseMessages, skillPrompt, evolutionPrompt);
    _skillRegistry?.clearContext();

    try {
      for (var iteration = 0; iteration < maxIterations; iteration++) {
        cancelToken?.throwIfCancelled();

        final tools = _buildTools();
        final request = ChatCompletionCreateRequest(
          model: model.modelId,
          messages: messages,
          tools: tools,
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
            final rc = delta.reasoningContent ?? delta.reasoning;
            if (rc != null && rc.isNotEmpty) {
              yield AgentEvent.reasoning(rc);
            }
          }

          final td = chunk.textDelta;
          if (td != null && td.isNotEmpty) {
            yield AgentEvent.text(td);
          }
        }

        _logUsage(accumulator.usage);
        final usage = accumulator.usage;
        if (usage != null) {
          yield AgentEvent.usage(TokenUsage(
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens,
            totalTokens: usage.totalTokens,
            reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
            cachedTokens: usage.promptTokensDetails?.cachedTokens,
          ));
        }

        final toolCalls = accumulator.toolCalls;
        if (toolCalls.isEmpty) {
          yield AgentEvent.done(content: accumulator.content);
          return;
        }

        // 产出 tool_call 事件
        for (final tc in toolCalls) {
          yield AgentEvent.toolCall(
            id: tc.id,
            name: tc.function.name,
            arguments: tc.function.arguments,
          );
        }

        // 追加 assistant 消息（含 tool_calls）
        final rc = model.reasoning && accumulator.reasoningContent.isNotEmpty
            ? accumulator.reasoningContent
            : null;
        messages.add(AssistantMessage(
          content: accumulator.content.isNotEmpty ? accumulator.content : null,
          toolCalls: toolCalls,
          reasoningContent: rc,
        ));

        // 执行每个工具调用
        final toolCallDataList = <Map<String, dynamic>>[];
        for (final tc in toolCalls) {
          final result = await _executeToolCall(
            toolCall: tc,
            permissionService: permissionService,
            onPermission: onPermission,
            cancelToken: cancelToken,
            sentinelId: sentinelId,
            auxiliaryModel: auxiliaryModel,
            auxiliaryModelProvider: auxiliaryModelProvider,
          );

          yield result.event;
          messages.add(ChatMessage.tool(
            toolCallId: tc.id,
            content: result.processedResult,
          ));
          toolCallDataList.add({
            'id': tc.id,
            'name': tc.function.name,
            'arguments': tc.function.arguments,
            'result': result.rawResult,
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

  // ─── 内部 ─────────────────────────────────────────────────

  /// 首轮注入 skill / evolution prompt。
  List<ChatMessage> _injectPrompts(
    List<ChatMessage> base,
    String? skillPrompt,
    String? evolutionPrompt,
  ) {
    var messages = List<ChatMessage>.from(base);
    if (skillPrompt != null && skillPrompt.isNotEmpty) {
      messages = [ChatMessage.system(skillPrompt), ...messages];
    }
    if (evolutionPrompt != null && evolutionPrompt.isNotEmpty) {
      messages = [ChatMessage.system(evolutionPrompt), ...messages];
    }
    return messages;
  }

  /// 从 ToolRegistry 构建 OpenAI Tool 列表。
  List<Tool>? _buildTools() {
    final defs = _toolRegistry.definitions;
    if (defs.isEmpty) return null;
    return defs
        .map((t) => Tool.function(
              name: t['function']['name'] as String,
              description: t['function']['description'] as String,
              parameters: t['function']['parameters'] as Map<String, dynamic>,
            ))
        .toList();
  }

  /// 执行单个工具调用：权限检查 → 执行 → 摘要。
  Future<_ToolCallResult> _executeToolCall({
    required ToolCall toolCall,
    required PermissionService? permissionService,
    required PermissionCallback? onPermission,
    required CancelToken? cancelToken,
    String? sentinelId,
    ModelEntity? auxiliaryModel,
    ProviderEntity? auxiliaryModelProvider,
  }) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }

    final tool = _toolRegistry.get(toolCall.function.name);

    // 权限检查
    final ruleMatched =
        permissionService?.check(toolCall.function.name, args) == true;

    if (!ruleMatched) {
      if (onPermission == null) {
        const msg = 'Error: Tool requires user approval but no permission '
            'callback is configured.';
        return _ToolCallResult(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
          ),
          processedResult: msg,
          rawResult: msg,
        );
      }
      final approved = cancelToken == null
          ? await onPermission(toolCall.function.name, toolCall.function.arguments)
          : await Future.any<bool>([
              onPermission(toolCall.function.name, toolCall.function.arguments),
              cancelToken.whenCancelled.then((_) => false),
            ]);
      cancelToken?.throwIfCancelled();
      if (!approved) {
        const msg = 'User denied the tool execution.';
        return _ToolCallResult(
          event: AgentToolResultEvent(
            id: toolCall.id,
            name: toolCall.function.name,
            result: msg,
          ),
          processedResult: msg,
          rawResult: msg,
        );
      }
    }

    cancelToken?.throwIfCancelled();
    if (sentinelId != null) {
      args['_sentinel_id'] = sentinelId;
    }

    final rawResult = tool != null
        ? await tool.execute(args)
        : 'Error: Unknown tool "${toolCall.function.name}"';

    var processed = smartTruncate(rawResult);
    if (auxiliaryModel != null && auxiliaryModelProvider != null) {
      if (processed.length > 4000) {
        final summary = await _summarizeToolResult(
          toolName: toolCall.function.name,
          result: processed,
          auxModel: auxiliaryModel,
          auxProvider: auxiliaryModelProvider,
        );
        if (summary != null && summary.isNotEmpty) {
          processed = summary;
        }
      }
    }

    return _ToolCallResult(
      event: AgentToolResultEvent(
        id: toolCall.id,
        name: toolCall.function.name,
        result: rawResult,
      ),
      processedResult: processed,
      rawResult: rawResult,
    );
  }

  void _logUsage(Usage? usage) {
    if (!kDebugMode) return;
    if (usage != null) {
      LoggerUtil.d(
        'agent usage: prompt=${usage.promptTokens} '
        'completion=${usage.completionTokens} '
        'total=${usage.totalTokens} '
        'cached=${usage.promptTokensDetails?.cachedTokens}',
      );
    } else {
      LoggerUtil.w(
        'agent usage: provider 返回的流中未携带 usage（多数是该 '
        'provider/model 不支持 stream_options.include_usage）',
      );
    }
  }

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

/// 单个工具调用的执行结果。
class _ToolCallResult {
  final AgentToolResultEvent event;
  final String processedResult;
  final String rawResult;
  const _ToolCallResult({
    required this.event,
    required this.processedResult,
    required this.rawResult,
  });
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

  const factory AgentEvent.usage(TokenUsage usage) = AgentUsageEvent;
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

class AgentUsageEvent extends AgentEvent {
  final TokenUsage usage;
  const AgentUsageEvent(this.usage);
}
