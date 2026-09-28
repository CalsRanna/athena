import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:athena_core/service/completion_details.dart';
import 'package:openai_dart/openai_dart.dart';

/// Responses API 与 Chat Completions 形状之间的转换。
///
/// Athena 的上层（`AgentService`、`ChatStreamAccumulator`、
/// `ChatMessageConverter`）全部按 Chat Completions 的形状工作，接入 Responses
/// 时只在适配器里做双向映射：请求侧把 [ChatCompletionCreateRequest] 摊平成
/// `input` items，响应侧把 SSE 事件归一成 [ChatStreamEvent]。推理摘要走公共
/// 文本事件，原生输出经 [ResponsesStateChunk] 独立保存供下一次请求回传。
///
/// 表达不了的内容（音频、文件、JSON Schema 输出格式）一律显式抛错，
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
  checkRequestFields(request, 'Responses', {
    'model',
    'messages',
    'tools',
    'tool_choice',
    'parallel_tool_calls',
    'temperature',
    'top_p',
    'max_tokens',
    'max_completion_tokens',
    'reasoning_effort',
    'response_format',
    'verbosity',
    'metadata',
    'service_tier',
    'prompt_cache_key',
    'safety_identifier',
    'store',
    'stream_options',
    'frequency_penalty',
    'presence_penalty',
    'moderation',
    'top_logprobs',
  });
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
        if (state != null &&
            provider != null &&
            state.matches(provider, request.model, message)) {
          items.addAll(state.output);
          break;
        }
        if (message.refusal?.isNotEmpty == true) {
          items.add({
            'type': 'message',
            'role': 'assistant',
            'content': [
              if (content != null && content.isNotEmpty)
                {
                  'type': 'output_text',
                  'text': content,
                  'annotations': <dynamic>[],
                },
              {'type': 'refusal', 'refusal': message.refusal},
            ],
          });
        } else if (content != null && content.isNotEmpty) {
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
          FunctionCallOutputItem.string(
            callId: toolCallId,
            output: content,
          ).toJson(),
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
    topP: request.topP,
    maxOutputTokens: request.maxCompletionTokens ?? request.maxTokens,
    toolChoice: _responseToolChoice(request.toolChoice),
    parallelToolCalls: request.parallelToolCalls,
    metadata: request.metadata,
    serviceTier: request.serviceTier == null
        ? null
        : ServiceTier.fromJson(request.serviceTier!),
    promptCacheKey: request.promptCacheKey,
    safetyIdentifier: request.safetyIdentifier,
    frequencyPenalty: request.frequencyPenalty,
    presencePenalty: request.presencePenalty,
    moderation: request.moderation,
    topLogprobs: request.topLogprobs,
    // 两侧共用同一个 ReasoningEffort 枚举，Athena 侧已把 unknown 归一成 null
    reasoning: request.reasoningEffort == null
        ? null
        : ReasoningConfig(
            effort: request.reasoningEffort,
            summary: request.reasoningEffort == ReasoningEffort.none
                ? null
                : ReasoningSummary.auto,
          ),
    store: request.store ?? false,
    include: const [Include.reasoningEncryptedContent],
    text: _toTextConfig(request.responseFormat, request.verbosity),
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
  final calls = <int, FunctionCallOutputItemResponse>{};
  final arguments = <int, String>{};
  final texts = <(int, int), String>{};
  final reasoning = _ReasoningText();
  final refusals = <(int, int), String>{};
  var terminated = false;

  ChatStreamEvent refusalDelta((int, int) key, String delta) {
    refusals[key] = '${refusals[key] ?? ''}$delta';
    return _chunk(ChatDelta(content: delta, refusal: delta));
  }

  String suffix(String prior, String complete) {
    if (!complete.startsWith(prior)) {
      throw const FormatException(
        'Responses output differs from its streamed prefix',
      );
    }
    return complete.substring(prior.length);
  }

  ChatStreamEvent textDelta((int, int) key, String delta) {
    texts[key] = '${texts[key] ?? ''}$delta';
    return _chunk(ChatDelta(content: delta));
  }

  Stream<ChatStreamEvent> finishPart(
    (int, int) key,
    Map<String, dynamic> part,
  ) async* {
    if (part['type'] == 'output_text') {
      final delta = suffix(texts[key] ?? '', part['text'] as String);
      if (delta.isNotEmpty) yield textDelta(key, delta);
    } else if (part['type'] == 'refusal') {
      final delta = suffix(refusals[key] ?? '', part['refusal'] as String);
      if (delta.isNotEmpty) yield refusalDelta(key, delta);
    }
  }

  Stream<ChatStreamEvent> argumentDelta(int outputIndex, String delta) async* {
    if (delta.isEmpty) return;
    arguments[outputIndex] = '${arguments[outputIndex] ?? ''}$delta';
    final index = callIndexes[outputIndex];
    if (index != null) {
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
    }
  }

  Stream<ChatStreamEvent> finishArguments(
    int outputIndex,
    String complete,
  ) async* {
    yield* argumentDelta(
      outputIndex,
      suffix(arguments[outputIndex] ?? '', complete),
    );
  }

  // added / done / completed 都可能是首次携带完整内容的事件；仅补齐未发出的后缀。
  Stream<ChatStreamEvent> finishItem(int outputIndex, OutputItem item) async* {
    if (item is FunctionCallOutputItemResponse) {
      final prior = calls[outputIndex];
      if (prior != null &&
          (prior.callId != item.callId || prior.name != item.name)) {
        throw const FormatException('Responses function call identity changed');
      }
      if (prior == null) {
        final index = callIndexes.length;
        callIndexes[outputIndex] = index;
        calls[outputIndex] = item;
        yield _chunk(
          ChatDelta(
            toolCalls: [
              ToolCallDelta(
                index: index,
                id: item.callId,
                type: 'function',
                function: FunctionCallDelta(
                  name: item.name,
                  arguments: arguments[outputIndex],
                ),
              ),
            ],
          ),
        );
      }
      yield* finishArguments(outputIndex, item.arguments);
    } else {
      final content = item.toJson()['content'];
      if (content is! List) return;
      for (var j = 0; j < content.length; j++) {
        yield* finishPart((outputIndex, j), content[j] as Map<String, dynamic>);
      }
    }
  }

  Stream<ChatStreamEvent> finishOutput(Response response) async* {
    for (var i = 0; i < response.output.length; i++) {
      yield* finishItem(i, response.output[i]);
    }
  }

  await for (final event in events) {
    switch (event) {
      case OutputItemAddedEvent(:final outputIndex, :final item):
        yield* finishItem(outputIndex, item);

      case RefusalDeltaEvent(
        :final outputIndex,
        :final contentIndex,
        :final delta,
      ):
        yield refusalDelta((outputIndex, contentIndex), delta);
      case RefusalDoneEvent(
        :final outputIndex,
        :final contentIndex,
        :final refusal,
      ):
        final key = (outputIndex, contentIndex);
        final prior = refusals[key] ?? '';
        if (!refusal.startsWith(prior)) {
          throw const FormatException('Refusal prefix mismatch');
        }
        if (refusal.length > prior.length) {
          yield refusalDelta(key, refusal.substring(prior.length));
        }

      case OutputTextDeltaEvent(
        :final outputIndex,
        :final contentIndex,
        :final delta,
      ):
        if (delta.isNotEmpty) {
          yield textDelta((outputIndex, contentIndex), delta);
        }

      case OutputTextDoneEvent(
        :final outputIndex,
        :final contentIndex,
        :final text,
      ):
        yield* finishPart(
          (outputIndex, contentIndex),
          {'type': 'output_text', 'text': text},
        );

      case ContentPartAddedEvent(
        :final outputIndex,
        :final contentIndex,
        :final part,
      ):
        yield* finishPart((outputIndex, contentIndex), part.toJson());

      case ContentPartDoneEvent(
        :final outputIndex,
        :final contentIndex,
        :final part,
      ):
        yield* finishPart((outputIndex, contentIndex), part.toJson());

      case ReasoningTextDeltaEvent(
        :final outputIndex,
        :final contentIndex,
        :final delta,
      ):
        yield* reasoning.add((outputIndex, false, contentIndex ?? 0), delta);

      case ReasoningSummaryTextDeltaEvent(
        :final outputIndex,
        :final summaryIndex,
        :final delta,
      ):
        yield* reasoning.add((outputIndex, true, summaryIndex), delta);

      case ReasoningTextDoneEvent(
        :final outputIndex,
        :final contentIndex,
        :final text,
      ):
        yield* reasoning.finish((outputIndex, false, contentIndex ?? 0), text);

      case ReasoningSummaryTextDoneEvent(
        :final outputIndex,
        :final summaryIndex,
        :final text,
      ):
        yield* reasoning.finish((outputIndex, true, summaryIndex), text);

      case OutputItemDoneEvent(:final outputIndex, :final item):
        if (item is ReasoningItem) yield* reasoning.item(outputIndex, item);
        yield* finishItem(outputIndex, item);

      case FunctionCallArgumentsDeltaEvent(:final outputIndex, :final delta):
        yield* argumentDelta(outputIndex, delta);

      case FunctionCallArgumentsDoneEvent(:final outputIndex, :final arguments):
        yield* finishArguments(outputIndex, arguments);

      case ResponseCompletedEvent(:final response):
        terminated = true;
        yield* reasoning.response(response);
        yield* finishOutput(response);
        yield CompletionDetailsChunk(_responseDetails(response));
        yield _terminalChunk(
          response: response,
          finishReason: _responseFinishReason(response),
        );
        final state = _responseState(response, provider, model);
        if (state != null) yield ResponsesStateChunk(state);

      case ResponseIncompleteEvent(:final response):
        terminated = true;
        yield* reasoning.response(response);
        yield* finishOutput(response);
        yield CompletionDetailsChunk(_responseDetails(response));
        // 保留截断原因；length 与 content_filter 都不得执行工具。
        yield _terminalChunk(
          response: response,
          finishReason: _responseFinishReason(response),
        );

      case ResponseFailedEvent(:final response):
        throw _responseError(
          response.error?.code ?? 'server_error',
          response.error?.message ?? 'Responses request failed',
        );

      case ErrorEvent(:final code, :final message):
        throw _responseError(code, message);

      default:
        break;
    }
  }
  if (!terminated) {
    throw StateError('Responses stream ended before a terminal event');
  }
  if (arguments.keys.any((index) => !callIndexes.containsKey(index))) {
    throw StateError('Responses function call is missing its identity');
  }
}

/// 把 Responses 的完整响应转成 Chat Completion（非流式路径）。
ChatCompletion responseToChatCompletion(
  Response response, {
  ProviderEntity? provider,
  String? model,
}) {
  final finishReason = _responseFinishReason(response);
  return DetailedChatCompletion(
    details: _responseDetails(response),
    id: response.id,
    object: 'chat.completion',
    created: response.createdAt,
    model: response.model ?? '',
    choices: [
      ChatChoice(
        index: 0,
        message: ResponsesAssistantMessage(
          content: response.outputText,
          refusal: _responseRefusal(response),
          reasoningContent: _reasoningContent(response),
          toolCalls: _toolCalls(response),
          responsesState: _responseState(
            response,
            provider,
            model,
            message: AssistantMessage(
              content: response.outputText,
              toolCalls: _toolCalls(response),
            ),
          ),
        ),
        finishReason: finishReason,
      ),
    ],
    usage: _toUsage(response.usage),
  );
}

List<ToolCall>? _toolCalls(Response response) {
  if (response.functionCalls.isEmpty) return null;
  return response.functionCalls
      .map(
        (call) => ToolCall(
          id: call.callId,
          type: 'function',
          function: FunctionCall(name: call.name, arguments: call.arguments),
        ),
      )
      .toList();
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

ResponsesState? _responseState(
  Response response,
  ProviderEntity? provider,
  String? model, {
  AssistantMessage? message,
}) {
  if (provider == null ||
      model == null ||
      response.status != ResponseStatus.completed ||
      response.reasoningItems.isEmpty) {
    return null;
  }
  return ResponsesState(
    provider: provider,
    model: model,
    output: response.output.map((item) => item.toJson()).toList(),
    message:
        message ??
        AssistantMessage(
          content: _responseVisibleText(response),
          toolCalls: _toolCalls(response),
        ),
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
      throw const FormatException(
        'Reasoning text differs from its streamed prefix.',
      );
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
        if (content[i]['type'] == 'reasoning_text' &&
            content[i]['text'] is String) {
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
      throw UnsupportedError('Responses 协议暂不支持 ${part.runtimeType} 类型的消息内容');
  }
}

ResponseTool _toResponseTool(Tool tool) {
  return FunctionTool(
    name: tool.function.name,
    description: tool.function.description,
    parameters: tool.function.parameters,
    strict: tool.function.strict,
  );
}

ResponseToolChoice? _responseToolChoice(ToolChoice? choice) {
  return switch (choice) {
    null => null,
    ToolChoiceAuto() => ResponseToolChoice.auto,
    ToolChoiceNone() => ResponseToolChoice.none,
    ToolChoiceRequired() => ResponseToolChoice.required,
    ToolChoiceFunction(:final name) => ResponseToolChoice.function(name: name),
    _ => throw UnsupportedError(
      'Responses does not support ${choice.runtimeType}',
    ),
  };
}

TextConfig? _toTextConfig(ResponseFormat? format, Verbosity? verbosity) {
  final TextFormat? native = switch (format) {
    null => null,
    TextResponseFormat() => const PlainTextFormat(),
    JsonObjectResponseFormat() => const JsonObjectFormat(),
    _ => throw UnsupportedError(
      'Responses 协议暂不支持 ${format.runtimeType} 形式的 response_format',
    ),
  };
  return native == null && verbosity == null
      ? null
      : TextConfig(format: native, verbosity: verbosity);
}

String? _responseRefusal(Response response) {
  final text = [
    for (final item in response.output)
      for (final part in (item.toJson()['content'] as List? ?? const []))
        if (part['type'] == 'refusal') part['refusal'] as String,
  ].join();
  return text.isEmpty ? null : text;
}

String _responseVisibleText(Response response) => [
  for (final item in response.output)
    for (final part in (item.toJson()['content'] as List? ?? const []))
      if (part['type'] == 'output_text')
        part['text'] as String
      else if (part['type'] == 'refusal')
        part['refusal'] as String,
].join();

Map<String, dynamic> _responseDetails(Response response) => {
  'protocol': 'responses',
  'status': response.status.name,
  if (response.incompleteDetails != null)
    'incomplete_details': response.incompleteDetails!.toJson(),
  if (response.error != null) 'error': response.error!.toJson(),
  if (_responseRefusal(response) case final String refusal) 'refusal': refusal,
  if (response.usage != null) 'usage': response.usage!.toJson(),
};

FinishReason _responseFinishReason(Response response) {
  switch (response.status) {
    case ResponseStatus.completed:
      if (_responseRefusal(response) != null) return FinishReason.contentFilter;
      return response.functionCalls.isEmpty
          ? FinishReason.stop
          : FinishReason.toolCalls;
    case ResponseStatus.incomplete:
      final reason = response.incompleteDetails?.toJson()['reason'];
      if (reason == 'max_output_tokens') return FinishReason.length;
      if (reason == 'content_filter') return FinishReason.contentFilter;
      throw StateError('Unsupported Responses incomplete reason: $reason');
    case ResponseStatus.failed:
      throw _responseError(
        response.error?.code ?? 'server_error',
        response.error?.message ?? 'Responses request failed',
      );
    default:
      throw StateError(
        'Responses request has not completed: ${response.status.name}',
      );
  }
}

ApiException _responseError(String code, String message) => switch (code) {
  'rate_limit_exceeded' => RateLimitException(message: message),
  'server_error' || 'internal_server_error' => InternalServerException(
    statusCode: 500,
    message: message,
  ),
  _ => ApiException(statusCode: 400, message: '$code: $message'),
};
