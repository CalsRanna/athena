import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:openai_dart/openai_dart.dart';

/// Responses API 与 Chat Completions 形状之间的转换。
///
/// Athena 的上层（`AgentService`、`ChatStreamAccumulator`、
/// `ChatMessageConverter`）全部按 Chat Completions 的形状工作，接入 Responses
/// 时只在适配器里做双向映射：请求侧把 [ChatCompletionCreateRequest] 摊平成
/// `input` items，响应侧把 SSE 事件归一成 [ChatStreamEvent]。推理摘要走公共
/// 文本事件，原生输出经 [ResponsesStateChunk] 独立保存供下一次请求回传。
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
  ProviderEntity? provider,
}) {
  final instructions = <String>[];
  final items = <Map<String, dynamic>>[];

  for (final message in request.messages) {
    switch (message) {
      case SystemMessage(:final content):
        if (content.isNotEmpty) instructions.add(content);
      case DeveloperMessage(:final content):
        if (content.isNotEmpty) instructions.add(content);
      case UserMessage(:final content):
        items.add(_toUserItem(content).toJson());
      case AssistantMessage(:final content, :final toolCalls):
        final state = message is ResponsesAssistantMessage
            ? message.responsesState
            : null;
        if (state != null && provider != null &&
            state.matches(provider, request.model, message)) {
          items.addAll(state.output);
          break;
        }
        if (content != null && content.isNotEmpty) {
          items.add(MessageItem.assistantText(content).toJson());
        }
        // 每个 tool call 是一个独立 item，callId 必须原样回传，
        // 否则下一轮的 function_call_output 对不上。
        for (final call in toolCalls ?? const <ToolCall>[]) {
          items.add(
            FunctionCallItem(
              callId: call.id,
              name: call.function.name,
              arguments: call.function.arguments,
            ).toJson(),
          );
        }
      case ToolMessage(:final toolCallId, :final content):
        items.add(
          FunctionCallOutputItem.string(callId: toolCallId, output: content).toJson(),
        );
    }
  }

  return CreateResponseRequest(
    model: request.model,
    // SDK 的 Item 类型不含 reasoning；raw output input 可原样携带密文与 item id。
    input: ResponseInput.fromOutputItems(items),
    instructions: instructions.isEmpty ? null : instructions.join('\n\n'),
    tools: request.tools?.map(_toResponseTool).toList(),
    temperature: request.temperature,
    // 两侧共用同一个 ReasoningEffort 枚举，Athena 侧已把 unknown 归一成 null
    reasoning: request.reasoningEffort == null
        ? null
        : ReasoningConfig(
            effort: request.reasoningEffort,
            summary: request.reasoningEffort == ReasoningEffort.none
                ? null : ReasoningSummary.auto,
          ),
    store: false,
    include: const [Include.reasoningEncryptedContent],
    text: _toTextConfig(request.responseFormat),
    stream: stream,
  );
}

/// 把 Responses 的流式事件归一成 Chat Completions 形状的流。
Stream<ChatStreamEvent> normalizeResponsesStream(
  Stream<ResponseStreamEvent> events, {
  ProviderEntity? provider,
  String? model,
}) async* {
  // function call 的索引按出现顺序重新编号：ChatStreamAccumulator 把
  // tool_calls 的 index 直接当列表下标用，而 Responses 的 outputIndex 会
  // 因为 reasoning / message item 占据槽位而出现空洞。
  // 键用 outputIndex：参数增量事件的 item_id 是 item 自身的 id（fc_…），
  // 与 call_id（call_…）不是同一个值，且可为空；outputIndex 两边都必有。
  final callIndexes = <int, int>{};
  final reasoning = _ReasoningText();

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

      case ReasoningTextDeltaEvent(:final outputIndex, :final contentIndex, :final delta):
        yield* reasoning.add((outputIndex, false, contentIndex ?? 0), delta);

      case ReasoningSummaryTextDeltaEvent(:final outputIndex, :final summaryIndex, :final delta):
        yield* reasoning.add((outputIndex, true, summaryIndex), delta);

      case ReasoningTextDoneEvent(:final outputIndex, :final contentIndex, :final text):
        yield* reasoning.finish((outputIndex, false, contentIndex ?? 0), text);

      case ReasoningSummaryTextDoneEvent(:final outputIndex, :final summaryIndex, :final text):
        yield* reasoning.finish((outputIndex, true, summaryIndex), text);

      case OutputItemDoneEvent(:final outputIndex, :final item):
        if (item is ReasoningItem) yield* reasoning.item(outputIndex, item);

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
        yield* reasoning.response(response);
        yield _terminalChunk(
          response: response,
          finishReason: FinishReason.stop,
        );
        final state = _responseState(response, provider, model);
        if (state != null) yield ResponsesStateChunk(state);

      case ResponseIncompleteEvent(:final response):
        yield* reasoning.response(response);
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
ChatCompletion responseToChatCompletion(Response response, {
  ProviderEntity? provider,
  String? model,
}) {
  return ChatCompletion(
    id: response.id,
    object: 'chat.completion',
    created: response.createdAt,
    model: response.model ?? '',
    choices: [
      ChatChoice(
        index: 0,
        message: ResponsesAssistantMessage(
          content: response.outputText,
          reasoningContent: _reasoningContent(response),
          toolCalls: _toolCalls(response),
          responsesState: _responseState(response, provider, model),
        ),
        finishReason: response.status == ResponseStatus.incomplete
            ? FinishReason.length
            : FinishReason.stop,
      ),
    ],
    usage: _toUsage(response.usage),
  );
}

List<ToolCall>? _toolCalls(Response response) {
  if (response.functionCalls.isEmpty) return null;
  return response.functionCalls.map((call) => ToolCall(
    id: call.callId,
    type: 'function',
    function: FunctionCall(name: call.name, arguments: call.arguments),
  )).toList();
}

String? _reasoningContent(Response response) {
  final parts = <String>[];
  for (final item in response.reasoningItems) {
    if (item.summary.isNotEmpty) {
      parts.addAll(item.summary.map((part) => part.text));
    } else {
      for (final part in item.content ?? <Map<String, dynamic>>[]) {
        if (part['type'] == 'reasoning_text' && part['text'] is String) {
          parts.add(part['text'] as String);
        }
      }
    }
  }
  return parts.isEmpty ? null : parts.join('\n\n');
}

ResponsesState? _responseState(Response response, ProviderEntity? provider, String? model) {
  if (provider == null || model == null ||
      response.status != ResponseStatus.completed || response.reasoningItems.isEmpty) {
    return null;
  }
  return ResponsesState(
    provider: provider,
    model: model,
    output: response.output.map((item) => item.toJson()).toList(),
    message: AssistantMessage(content: response.outputText, toolCalls: _toolCalls(response)),
    reasoningTokens: response.usage?.outputTokensDetails?.reasoningTokens ?? 0,
  );
}

/// delta、done 和终态都可能含摘要；按 item/part 去重，保留多段摘要的边界。
class _ReasoningText {
  final _parts = <(int, bool, int), String>{};
  bool _hasText = false;

  Stream<ChatStreamEvent> add((int, bool, int) key, String delta) async* {
    if (delta.isEmpty) return;
    final separator = !_parts.containsKey(key) && _hasText ? '\n\n' : '';
    _parts[key] = '${_parts[key] ?? ''}$delta';
    _hasText = true;
    yield _chunk(ChatDelta(reasoningContent: '$separator$delta'));
  }

  Stream<ChatStreamEvent> finish((int, bool, int) key, String text) async* {
    final prior = _parts[key] ?? '';
    if (!text.startsWith(prior)) {
      throw const FormatException('Reasoning text differs from its streamed prefix.');
    }
    yield* add(key, text.substring(prior.length));
  }

  Stream<ChatStreamEvent> item(int index, ReasoningItem item) async* {
    for (var i = 0; i < item.summary.length; i++) {
      yield* finish((index, true, i), item.summary[i].text);
    }
    if (item.summary.isEmpty) {
      final content = item.content ?? <Map<String, dynamic>>[];
      for (var i = 0; i < content.length; i++) {
        if (content[i]['type'] == 'reasoning_text' && content[i]['text'] is String) {
          yield* finish((index, false, i), content[i]['text'] as String);
        }
      }
    }
  }

  Stream<ChatStreamEvent> response(Response response) async* {
    for (var i = 0; i < response.output.length; i++) {
      final output = response.output[i];
      if (output is ReasoningItem) yield* item(i, output);
    }
  }
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
