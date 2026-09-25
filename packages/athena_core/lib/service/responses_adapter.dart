import 'dart:async';

import 'package:openai_dart/openai_dart.dart';

/// Responses API 与 Chat Completions 形状之间的转换。
///
/// Athena 的上层（`AgentService`、`ChatStreamAccumulator`、
/// `ChatMessageConverter`）全部按 Chat Completions 的形状工作，接入 Responses
/// 时只在适配器里做双向映射：请求侧把 [ChatCompletionCreateRequest] 摊平成
/// `input` items，响应侧把 SSE 事件归一成 [ChatStreamEvent]。上层因此不需要
/// 感知协议差异。
///
/// 表达不了的内容（音频、文件、refusal、JSON Schema 输出格式）一律显式抛错，
/// 不静默丢弃——静默丢弃会让模型收到残缺上下文却看不出原因。

/// 把 Chat Completions 形状的请求转成 Responses 请求。
///
/// system / developer 消息并入 `instructions`（Responses 的等价位置），
/// 其余消息按角色摊平成 input items：assistant 的 tool_calls 变成
/// `function_call` item，tool 结果变成 `function_call_output` item。
CreateResponseRequest toResponseRequest(
  ChatCompletionCreateRequest request, {
  bool stream = false,
}) {
  final instructions = <String>[];
  final items = <Item>[];

  for (final message in request.messages) {
    switch (message) {
      case SystemMessage(:final content):
        if (content.isNotEmpty) instructions.add(content);
      case DeveloperMessage(:final content):
        if (content.isNotEmpty) instructions.add(content);
      case UserMessage(:final content):
        items.add(_toUserItem(content));
      case AssistantMessage(:final content, :final toolCalls):
        if (content != null && content.isNotEmpty) {
          items.add(MessageItem.assistantText(content));
        }
        // 每个 tool call 是一个独立 item，callId 必须原样回传，
        // 否则下一轮的 function_call_output 对不上。
        for (final call in toolCalls ?? const <ToolCall>[]) {
          items.add(
            FunctionCallItem(
              callId: call.id,
              name: call.function.name,
              arguments: call.function.arguments,
            ),
          );
        }
      case ToolMessage(:final toolCallId, :final content):
        items.add(
          FunctionCallOutputItem.string(callId: toolCallId, output: content),
        );
    }
  }

  return CreateResponseRequest(
    model: request.model,
    input: ResponseInputItems(items),
    instructions: instructions.isEmpty ? null : instructions.join('\n\n'),
    tools: request.tools?.map(_toResponseTool).toList(),
    temperature: request.temperature,
    // 两侧共用同一个 ReasoningEffort 枚举，Athena 侧已把 unknown 归一成 null
    reasoning: request.reasoningEffort == null
        ? null
        : ReasoningConfig(effort: request.reasoningEffort),
    text: _toTextConfig(request.responseFormat),
    stream: stream,
  );
}

/// 把 Responses 的流式事件归一成 Chat Completions 形状的流。
Stream<ChatStreamEvent> normalizeResponsesStream(
  Stream<ResponseStreamEvent> events,
) async* {
  // function call 的索引按出现顺序重新编号：ChatStreamAccumulator 把
  // tool_calls 的 index 直接当列表下标用，而 Responses 的 outputIndex 会
  // 因为 reasoning / message item 占据槽位而出现空洞。
  // 键用 outputIndex：参数增量事件的 item_id 是 item 自身的 id（fc_…），
  // 与 call_id（call_…）不是同一个值，且可为空；outputIndex 两边都必有。
  final callIndexes = <int, int>{};

  await for (final event in events) {
    switch (event) {
      case OutputItemAddedEvent(:final outputIndex, :final item):
        if (item is FunctionCallOutputItemResponse) {
          final index = callIndexes.length;
          callIndexes[outputIndex] = index;
          // id 与 name 同时给出，保证上层立刻能建卡
          // （AgentService 建卡条件是两者齐备）。
          yield _chunk(
            ChatDelta(
              toolCalls: [
                ToolCallDelta(
                  index: index,
                  id: item.callId,
                  type: 'function',
                  function: FunctionCallDelta(name: item.name),
                ),
              ],
            ),
          );
        }

      case OutputTextDeltaEvent(:final delta):
        if (delta.isNotEmpty) yield _chunk(ChatDelta(content: delta));

      case ReasoningTextDeltaEvent(:final delta):
        if (delta.isNotEmpty) yield _chunk(ChatDelta(reasoning: delta));

      case FunctionCallArgumentsDeltaEvent(:final outputIndex, :final delta):
        final index = callIndexes[outputIndex];
        if (index == null || delta.isEmpty) break;
        yield _chunk(
          ChatDelta(
            toolCalls: [
              ToolCallDelta(
                index: index,
                function: FunctionCallDelta(arguments: delta),
              ),
            ],
          ),
        );

      case ResponseCompletedEvent(:final response):
        yield _terminalChunk(
          response: response,
          finishReason: FinishReason.stop,
        );

      case ResponseIncompleteEvent(:final response):
        // 归一到 length：上层据此拒绝执行被截断的 tool_calls。
        yield _terminalChunk(
          response: response,
          finishReason: FinishReason.length,
        );

      case ResponseFailedEvent(:final response):
        throw StateError(
          'Responses 请求失败：${response.error?.message ?? response.status.name}',
        );

      default:
        break;
    }
  }
}

/// 把 Responses 的完整响应转成 Chat Completion（非流式路径）。
ChatCompletion responseToChatCompletion(Response response) {
  return ChatCompletion(
    id: response.id,
    object: 'chat.completion',
    created: response.createdAt,
    model: response.model ?? '',
    choices: [
      ChatChoice(
        index: 0,
        message: AssistantMessage(content: response.outputText),
        finishReason: response.status == ResponseStatus.incomplete
            ? FinishReason.length
            : FinishReason.stop,
      ),
    ],
    usage: _toUsage(response.usage),
  );
}

ChatStreamEvent _chunk(ChatDelta delta) {
  return ChatStreamEvent(
    object: 'chat.completion.chunk',
    choices: [ChatStreamChoice(index: 0, delta: delta)],
  );
}

ChatStreamEvent _terminalChunk({
  required Response response,
  required FinishReason finishReason,
}) {
  return ChatStreamEvent(
    id: response.id,
    object: 'chat.completion.chunk',
    model: response.model,
    choices: [
      ChatStreamChoice(
        index: 0,
        delta: const ChatDelta(),
        finishReason: finishReason,
      ),
    ],
    usage: _toUsage(response.usage),
  );
}

Usage? _toUsage(ResponseUsage? usage) {
  if (usage == null) return null;
  return Usage(
    promptTokens: usage.inputTokens,
    completionTokens: usage.outputTokens,
    totalTokens: usage.totalTokens,
    promptTokensDetails: PromptTokensDetails(
      cachedTokens: usage.inputTokensDetails?.cachedTokens,
    ),
    completionTokensDetails: CompletionTokensDetails(
      reasoningTokens: usage.outputTokensDetails?.reasoningTokens,
    ),
  );
}

Item _toUserItem(UserMessageContent content) {
  switch (content) {
    case UserTextContent(:final text):
      return MessageItem.userText(text);
    case UserPartsContent(:final parts):
      return MessageItem.user(parts.map(_toInputContent).toList());
  }
}

InputContent _toInputContent(ContentPart part) {
  switch (part) {
    case TextContentPart(:final text):
      return InputTextContent(text);
    case ImageContentPart(:final url, :final detail):
      // Responses 与 Chat Completions 都接受 data URL 或 http(s) URL，
      // 可直接沿用同一条 url。
      return InputImageContent.url(url, detail: detail);
    default:
      throw UnsupportedError(
        'Responses 协议暂不支持 ${part.runtimeType} 类型的消息内容',
      );
  }
}

ResponseTool _toResponseTool(Tool tool) {
  return FunctionTool(
    name: tool.function.name,
    description: tool.function.description,
    parameters: tool.function.parameters,
  );
}

TextConfig? _toTextConfig(ResponseFormat? format) {
  switch (format) {
    case null:
      return null;
    case JsonObjectResponseFormat():
      return const TextConfig(format: JsonObjectFormat());
    default:
      throw UnsupportedError(
        'Responses 协议暂不支持 ${format.runtimeType} 形式的 response_format',
      );
  }
}
