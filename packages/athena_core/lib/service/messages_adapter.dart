import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/messages_state.dart';
import 'package:athena_core/service/completion_details.dart';
import 'package:athena_core/service/messages_thinking.dart';
import 'package:openai_dart/openai_dart.dart';

/// Messages（Anthropic）与 Chat Completions 形状之间的转换。
///
/// 与 `responses_adapter.dart` 同一套路：Athena 上层（`AgentService`、
/// `ChatStreamAccumulator`、`ChatMessageConverter`）按 Chat Completions 形状
/// 工作，原生推理状态另经 MessagesStateChunk 保存与回传。
///
/// 与另两条协议的三处实质差异，都在这里消化：
/// 1. `system` 是顶层字段（不属于 messages），且 messages 必须 user /
///    assistant 交替，连续同角色要合并成一条多 block 的消息；
/// 2. 工具参数在 assistant 消息里是**对象**（`tool_use.input`），而流式里是
///    `input_json_delta` 分片，两侧都要与 Chat Completions 的 JSON 字符串互转；
/// 3. 用量字段名不同（`input_tokens` / `cache_read_input_tokens`），且 output
///    用量只在 `message_delta` 里给。
///
/// 表达不了的内容（JSON Schema 输出格式、文档与音频内容）显式抛错，不静默丢弃。

/// Messages 的 `max_tokens` 是必填项，而 Chat Completions 里 Athena 从不传。
/// 模型输出上限未知时的取值：与 `ContextBudget` 给输出预留的上限一致，且
/// 不超过常见模型的上限（超过模型上限的值会被直接拒绝）。
const _defaultMaxTokens = 8192;

/// 一次 Messages 请求的 `max_tokens`。
///
/// 模型输出上限已知（[outputLimit]，来自 models.dev）就用它：固定 8192 时，
/// 参数超过这个长度的工具调用（写一个大文件）每次都会被截断、被拒绝执行、
/// 再重发，直到迭代上限。再按窗口余量 [outputRoom] 收紧：「输入 +
/// max_tokens」超出窗口时请求同样会被拒绝。
int messagesMaxTokens({int outputLimit = 0, int? outputRoom}) {
  final cap = outputLimit > 0 ? outputLimit : _defaultMaxTokens;
  if (outputRoom == null) return cap;
  return max(1, min(cap, outputRoom));
}

/// 把 Chat Completions 形状的请求转成 Messages 请求。
///
/// 显式输出上限受 [maxTokens] 预算收紧；都未提供时用 [messagesMaxTokens]。
anthropic.MessageCreateRequest toMessageRequest(
  ChatCompletionCreateRequest request, {
  bool stream = false,
  int? maxTokens,
  ProviderEntity? provider,
}) {
  checkRequestFields(request, 'Messages', {
    'model', 'messages', 'tools', 'tool_choice', 'parallel_tool_calls',
    'temperature', 'top_p', 'top_k', 'max_tokens', 'max_completion_tokens',
    'reasoning_effort', 'response_format', 'stop', 'user', 'stream_options',
  });
  // 当前适配器尚未接入 output_config.format。
  // 不显式失败的话，`/json` 模式下会静默按普通对话发出，用户拿到的是
  // 「看起来生效但其实没有」的结果。
  if (request.responseFormat != null) {
    throw UnsupportedError(
      'Messages 协议暂不支持 ${request.responseFormat.runtimeType} 形式的 '
      'response_format',
    );
  }

  final system = <String>[
    for (final message in request.messages)
      if (message is SystemMessage && message.content.isNotEmpty)
        message.content
      else if (message is DeveloperMessage && message.content.isNotEmpty)
        message.content,
  ];
  final systemPrompt = system.isEmpty
      ? null : anthropic.SystemPrompt.text(system.join('\n\n'));
  final tools = request.tools?.map(_toToolDefinition).toList();
  final messages = <anthropic.InputMessage>[];
  final pending = <anthropic.InputContentBlock>[];
  _Role pendingRole = _Role.none;
  MessagesState? lastAssistantState;

  void flush() {
    if (pending.isEmpty) return;
    messages.add(
      pendingRole == _Role.user
          ? anthropic.InputMessage.userBlocks(List.of(pending))
          : anthropic.InputMessage.assistantBlocks(List.of(pending)),
    );
    pending.clear();
    pendingRole = _Role.none;
  }

  void push(_Role role, List<anthropic.InputContentBlock> blocks) {
    if (blocks.isEmpty) return;
    if (pendingRole != _Role.none && pendingRole != role) flush();
    pendingRole = role;
    pending.addAll(blocks);
  }

  for (final message in request.messages) {
    switch (message) {
      case SystemMessage():
        break;
      case DeveloperMessage():
        break;
      case UserMessage(:final content):
        push(_Role.user, _toUserBlocks(content));
      case AssistantMessage(:final content, :final toolCalls):
        lastAssistantState = null;
        if (message is MessagesAssistantMessage && provider != null) {
          final state = message.messagesState;
          flush();
          final prefix = MessagesState.hashJson({
            'system': systemPrompt?.toJson(),
            'tools': tools?.map((tool) => tool.toJson()).toList(),
            'messages': messages.map((message) => message.toJson()).toList(),
          });
          if (state != null &&
              state.matches(provider, request.model, message, prefix)) {
            lastAssistantState = state;
            push(_Role.assistant,
              state.content.map(anthropic.InputContentBlock.fromJson).toList());
            continue;
          }
        }
        final blocks = <anthropic.InputContentBlock>[
          if (content != null && content.isNotEmpty)
            anthropic.InputContentBlock.text(content),
          if (message.refusal?.isNotEmpty == true && message.refusal != content)
            anthropic.InputContentBlock.text(message.refusal!),
          for (final call in toolCalls ?? const <ToolCall>[])
            anthropic.InputContentBlock.toolUse(
              id: _toolUseId(call.id),
              name: call.function.name,
              // Chat Completions 里参数是 JSON 字符串，Messages 要对象；
              // 解析失败说明上游给的不是 JSON，按空对象下发让模型重试。
              input: _decodeArguments(call.function.arguments),
            ),
        ];
        push(_Role.assistant, blocks);
      case ToolMessage(:final toolCallId, :final content):
        push(_Role.user, [
          anthropic.InputContentBlock.toolResultText(
            toolUseId: _toolUseId(toolCallId),
            text: content,
          ),
        ]);
    }
  }
  flush();

  final explicitLimit = request.maxCompletionTokens ?? request.maxTokens;
  final outputLimit = explicitLimit == null
      ? maxTokens ?? messagesMaxTokens()
      : maxTokens == null ? explicitLimit : min(explicitLimit, maxTokens);
  var thinking = MessagesThinking.resolve(
    request.model, request.reasoningEffort, outputLimit);
  // 工具循环属于同一个 assistant turn，不能中途改变 thinking 配置。
  final continuation = request.messages.lastOrNull is ToolMessage
      ? lastAssistantState : null;
  if (continuation != null) {
    final config = continuation.thinking == null
        ? null : anthropic.ThinkingConfig.fromJson(continuation.thinking!);
    if (config is anthropic.ThinkingEnabled &&
        config.budgetTokens >= outputLimit) {
      throw StateError('Insufficient output room to continue Messages thinking');
    }
    thinking = MessagesThinking(
      config,
      continuation.outputConfig == null
          ? null : anthropic.OutputConfig.fromJson(continuation.outputConfig!),
      thinking.omitTemperature || config is anthropic.ThinkingEnabled ||
          config is anthropic.ThinkingAdaptive,
    );
  }
  return anthropic.MessageCreateRequest(
    model: request.model,
    maxTokens: outputLimit,
    system: systemPrompt,
    messages: messages,
    tools: tools,
    toolChoice: _messageToolChoice(request.toolChoice, request.parallelToolCalls),
    topP: request.topP,
    topK: request.topK,
    stopSequences: request.stop,
    metadata: request.user == null ? null : anthropic.Metadata(userId: request.user),
    thinking: thinking.thinking,
    outputConfig: thinking.outputConfig,
    // Messages 只接受 0–1，而会话温度按 OpenAI 口径可调到 2（移动端滑杆）：
    // 推理模式及新版 Claude 不接受自定义温度，必须省略。
    temperature: thinking.omitTemperature
        ? null : request.temperature?.clamp(0.0, 1.0).toDouble(),
    stream: stream,
  );
}

/// Messages 要求 tool_use id 只含字母、数字、`_`、`-`；历史里的 id 来自
/// 生成它的那家 provider（有的带 `.` / `:`，如 `functions.bash:0`），切到
/// Messages 后原样下发会让这个会话之后的每次请求都被拒绝。
///
/// 合法的 id 原样保留；否则替换非法字符并带上原 id 的短哈希，避免只差在
/// 非法字符上的两个 id 撞成同一个。tool_use 与 tool_result 两侧用同一个
/// 函数，映射保持一致。
String _toolUseId(String id) {
  if (_validToolUseId.hasMatch(id)) return id;
  final sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  // FNV-1a（32 位）：确定性、无需额外依赖
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(id)) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return '${sanitized}_${hash.toRadixString(16).padLeft(8, '0')}';
}

final _validToolUseId = RegExp(r'^[a-zA-Z0-9_-]+$');

/// 把 Messages 的流式事件归一成 Chat Completions 形状的流。
Stream<ChatStreamEvent> normalizeMessagesStream(
  Stream<anthropic.MessageStreamEvent> events, {
  ProviderEntity? provider,
  anthropic.MessageCreateRequest? request,
}) async* {
  // content block 下标 → toolCalls 下标：文本块也占下标，而
  // ChatStreamAccumulator 把 index 当列表下标用，必须重编号。
  final callIndexes = <int, int>{};
  final blocks = <int, Map<String, dynamic>>{};
  final arguments = <int, StringBuffer>{};
  final openBlocks = <int>{};
  final reasoningParts = <int>{};
  var messageStopped = false;
  anthropic.StopReason? stopReason;
  var outputTokens = 0;
  int? reasoningTokens;
  // 从 message_start 初始化输入/缓存计数，message_delta 只覆盖实际返回的字段。
  var inputTokens = 0;
  var cachedTokens = 0;
  var cacheCreationTokens = 0;
  final details = <String, dynamic>{'protocol': 'messages'};
  final rawUsage = <String, dynamic>{};
  var hasText = false;
  String? id;
  String? model;

  await for (final event in events) {
    switch (event) {
      case anthropic.MessageStartEvent(:final message):
        id = message.id;
        model = message.model;
        inputTokens = message.usage.inputTokens;
        cachedTokens = message.usage.cacheReadInputTokens ?? 0;
        cacheCreationTokens = message.usage.cacheCreationInputTokens ?? 0;
        rawUsage.addAll(message.usage.toJson());
        outputTokens = message.usage.outputTokens;
        reasoningTokens = message.usage.outputTokensDetails?.thinkingTokens;

      case anthropic.ContentBlockStartEvent(:final index, :final contentBlock):
        blocks[index] = contentBlock.toJson();
        openBlocks.add(index);
        if (contentBlock is anthropic.TextBlock && contentBlock.text.isNotEmpty) {
          hasText = true;
          yield _chunk(ChatDelta(content: contentBlock.text));
        } else if (contentBlock is anthropic.ThinkingBlock &&
            contentBlock.thinking.isNotEmpty) {
          final separator = reasoningParts.isEmpty ? '' : '\n\n';
          reasoningParts.add(index);
          yield _chunk(ChatDelta(
            reasoningContent: '$separator${contentBlock.thinking}'));
        }
        if (contentBlock is anthropic.ToolUseBlock) {
          final toolIndex = callIndexes.length;
          callIndexes[index] = toolIndex;
          // id 与 name 同时给出，保证上层立刻建卡。
          yield _chunk(
            ChatDelta(
              toolCalls: [
                ToolCallDelta(
                  index: toolIndex,
                  id: contentBlock.id,
                  type: 'function',
                  function: FunctionCallDelta(
                    name: contentBlock.name,
                    arguments: contentBlock.input.isEmpty
                        ? null : jsonEncode(contentBlock.input),
                  ),
                ),
              ],
            ),
          );
        }

      case anthropic.ContentBlockDeltaEvent(:final index, :final delta):
        switch (delta) {
          case anthropic.TextDelta(:final text):
            final block = blocks[index];
            if (block != null) block['text'] = '${block['text'] ?? ''}$text';
            if (text.isNotEmpty) {
              hasText = true;
              yield _chunk(ChatDelta(content: text));
            }
          case anthropic.ThinkingDelta(:final thinking):
            final block = blocks[index];
            if (block != null) {
              block['thinking'] = '${block['thinking'] ?? ''}$thinking';
            }
            if (thinking.isNotEmpty) {
              final separator = !reasoningParts.contains(index) &&
                  reasoningParts.isNotEmpty ? '\n\n' : '';
              reasoningParts.add(index);
              yield _chunk(ChatDelta(reasoningContent: '$separator$thinking'));
            }
          case anthropic.SignatureDelta(:final signature):
            final block = blocks[index];
            if (block != null) block['signature'] = signature;
          case anthropic.CitationsDelta(:final citation):
            final block = blocks[index];
            if (block != null) {
              (block['citations'] ??= <dynamic>[]).add(citation.toJson());
            }
          case anthropic.InputJsonDelta(:final partialJson):
            (arguments[index] ??= StringBuffer()).write(partialJson);
            final toolIndex = callIndexes[index];
            if (toolIndex == null || partialJson.isEmpty) break;
            yield _chunk(
              ChatDelta(
                toolCalls: [
                  ToolCallDelta(
                    index: toolIndex,
                    function: FunctionCallDelta(arguments: partialJson),
                  ),
                ],
              ),
            );
          default:
            break;
        }

      case anthropic.ContentBlockStopEvent(:final index):
        openBlocks.remove(index);

      case anthropic.MessageStopEvent():
        messageStopped = true;
        if (request != null && stopReason == null) {
          throw StateError('Messages stream ended without stop_reason');
        }
        if (request != null && openBlocks.isNotEmpty) {
          throw StateError('Messages stream ended with unfinished content blocks');
        }
        if (provider != null && request != null && id != null &&
            openBlocks.isEmpty && _completeStop(stopReason)) {
          for (final entry in arguments.entries) {
            blocks[entry.key]!['input'] = jsonDecode(entry.value.toString());
          }
          final content = blocks.values.toList();
          if (content.any((block) => block['type'] == 'thinking' ||
                  block['type'] == 'redacted_thinking') &&
              !MessagesState.hasCompleteThinking(content)) {
            throw StateError('Messages thinking response is missing its signature');
          }
          if (MessagesState.hasCompleteThinking(content)) {
            yield MessagesStateChunk(MessagesState(
              provider: provider,
              model: request.model,
              content: content,
              // 旧端点没有推理明细时，用总输出保守预留隐藏推理空间。
              reasoningTokens: reasoningTokens ?? outputTokens,
              prefixHash: MessagesState.hashPrefix(request),
              thinking: request.thinking?.toJson(),
              outputConfig: request.outputConfig?.toJson(),
              message: _assistantFromContent(content),
            ));
          }
        }

      case anthropic.MessageDeltaEvent(:final delta, :final usage):
        stopReason = delta.stopReason ?? stopReason;
        outputTokens = usage.outputTokens;
        inputTokens = usage.inputTokens ?? inputTokens;
        cachedTokens = usage.cacheReadInputTokens ?? cachedTokens;
        cacheCreationTokens = usage.cacheCreationInputTokens ?? cacheCreationTokens;
        rawUsage.addAll(usage.toJson());
        details.addAll(delta.toJson()..removeWhere((key, value) => value == null));
        details['usage'] = Map<String, dynamic>.of(rawUsage);
        yield CompletionDetailsChunk(Map<String, dynamic>.of(details));
        if (stopReason == anthropic.StopReason.refusal && !hasText) {
          final refusal = (details['stop_details'] as Map?)?['explanation'] as String?
              ?? 'Request refused.';
          hasText = true;
          yield _chunk(ChatDelta(content: refusal, refusal: refusal));
        }
        reasoningTokens = usage.outputTokensDetails?.thinkingTokens ?? reasoningTokens;
        yield _terminalChunk(
          id: id,
          model: model,
          finishReason: _finishReason(delta.stopReason),
          usage: _usage(
            inputTokens: usage.inputTokens ?? inputTokens,
            outputTokens: usage.outputTokens,
            cachedTokens: cachedTokens,
            cacheCreationTokens: cacheCreationTokens,
            reasoningTokens: reasoningTokens,
          ),
        );

      case anthropic.ErrorEvent(:final errorType, :final message):
        // 流内错误（最常见的是 overloaded_error）按对应的 HTTP 状态抛成 SDK
        // 的 ApiException：与请求阶段的错误同一种类型，重试判定只需看状态码
        throw anthropic.ApiException(
          statusCode: _statusForErrorType(errorType),
          message: '$errorType: $message',
        );

      default:
        break;
    }
  }
  // 提前 EOF 不能当成成功结束，否则会执行缺少完整续接状态的工具调用。
  if (request != null && !messageStopped) {
    throw StateError('Messages stream ended before message_stop');
  }
}

/// Anthropic 错误类型对应的 HTTP 状态（与请求阶段返回的状态码一致）。
/// 未知类型按服务端错误处理。
int _statusForErrorType(String errorType) => switch (errorType) {
  'invalid_request_error' => 400,
  'authentication_error' => 401,
  'permission_error' => 403,
  'not_found_error' => 404,
  'request_too_large' => 413,
  'rate_limit_error' => 429,
  'overloaded_error' => 529,
  _ => 500,
};

/// 把 Messages 的完整响应转成 Chat Completion（非流式路径）。
ChatCompletion messageToChatCompletion(anthropic.Message message, {
  ProviderEntity? provider,
  anthropic.MessageCreateRequest? request,
}) {
  final content = message.content.map((block) => block.toJson()).toList();
  final assistant = _assistantFromContent(content);
  final state = provider != null && request != null &&
      _completeStop(message.stopReason) &&
      MessagesState.hasCompleteThinking(content)
      ? MessagesState(
          provider: provider,
          model: request.model,
          content: content,
          reasoningTokens: message.usage.outputTokensDetails?.thinkingTokens ??
              message.usage.outputTokens,
          prefixHash: MessagesState.hashPrefix(request),
          thinking: request.thinking?.toJson(),
          outputConfig: request.outputConfig?.toJson(),
          message: assistant,
        ) : null;
  final refusal = message.stopReason == anthropic.StopReason.refusal
      ? assistant.content ?? message.stopDetails?.explanation ?? 'Request refused.' : null;
  return DetailedChatCompletion(
    details: {
      'protocol': 'messages',
      'stop_reason': message.stopReason?.value,
      'stop_sequence': message.stopSequence,
      if (message.stopDetails != null) 'stop_details': message.stopDetails!.toJson(),
      'usage': message.usage.toJson(),
    },
    id: message.id,
    object: 'chat.completion',
    model: message.model,
    choices: [
      ChatChoice(
        index: 0,
        message: MessagesAssistantMessage(
          content: assistant.content,
          refusal: refusal,
          toolCalls: assistant.toolCalls,
          reasoningContent: assistant.reasoningContent,
          messagesState: state,
        ),
        finishReason: _finishReason(message.stopReason),
      ),
    ],
    usage: _usage(
      inputTokens: message.usage.inputTokens,
      outputTokens: message.usage.outputTokens,
      cachedTokens: message.usage.cacheReadInputTokens ?? 0,
      cacheCreationTokens: message.usage.cacheCreationInputTokens ?? 0,
      reasoningTokens: message.usage.outputTokensDetails?.thinkingTokens,
    ),
  );
}

bool _completeStop(anthropic.StopReason? reason) =>
    reason == anthropic.StopReason.endTurn ||
    reason == anthropic.StopReason.toolUse ||
    reason == anthropic.StopReason.stopSequence;

AssistantMessage _assistantFromContent(List<Map<String, dynamic>> blocks) {
  final text = blocks.where((b) => b['type'] == 'text')
      .map((b) => b['text'] as String).join();
  final reasoning = blocks.where((b) => b['type'] == 'thinking')
      .map((b) => b['thinking'] as String)
      .where((s) => s.isNotEmpty).join('\n\n');
  final calls = [
    for (final block in blocks)
      if (block['type'] == 'tool_use')
        ToolCall(
          id: block['id'] as String,
          type: 'function',
          function: FunctionCall(
            name: block['name'] as String,
            arguments: jsonEncode(block['input']),
          ),
        ),
  ];
  return AssistantMessage(
    content: text.isEmpty ? null : text,
    reasoningContent: reasoning.isEmpty ? null : reasoning,
    toolCalls: calls.isEmpty ? null : calls,
  );
}

enum _Role { none, user, assistant }

List<anthropic.InputContentBlock> _toUserBlocks(UserMessageContent content) {
  switch (content) {
    case UserTextContent(:final text):
      return text.isEmpty ? const [] : [anthropic.InputContentBlock.text(text)];
    case UserPartsContent(:final parts):
      // 与纯文本分支同口径：空 text block 会被 Messages 协议 400 拒绝。
      return parts
          .where((part) => !(part is TextContentPart && part.text.isEmpty))
          .map(_toContentBlock)
          .toList();
  }
}

anthropic.InputContentBlock _toContentBlock(ContentPart part) {
  switch (part) {
    case TextContentPart(:final text):
      return anthropic.InputContentBlock.text(text);
    case ImageContentPart(:final url):
      return anthropic.InputContentBlock.image(_toImageSource(url));
    default:
      throw UnsupportedError(
        'Messages 协议暂不支持 ${part.runtimeType} 类型的消息内容',
      );
  }
}

/// Athena 的图片统一是 URL（http(s) 或 `data:` base64），而 Messages 把两者
/// 分成不同的 source 类型；`data:` 还要拆出媒体类型。
anthropic.ImageSource _toImageSource(String url) {
  if (!url.startsWith('data:')) return anthropic.ImageSource.url(url);

  final commaIndex = url.indexOf(',');
  if (commaIndex < 0) {
    throw UnsupportedError('Messages 协议无法解析该 data URL 图片');
  }
  final header = url.substring('data:'.length, commaIndex);
  final mediaType = header.split(';').first;
  anthropic.ImageMediaType? parsed;
  for (final candidate in anthropic.ImageMediaType.values) {
    if (candidate.value == mediaType) parsed = candidate;
  }
  if (parsed == null) {
    throw UnsupportedError('Messages 协议不支持 $mediaType 类型的图片');
  }
  return anthropic.ImageSource.base64(
    data: url.substring(commaIndex + 1),
    mediaType: parsed,
  );
}

anthropic.ToolDefinition _toToolDefinition(Tool tool) {
  return anthropic.ToolDefinition.custom(
    anthropic.Tool(
      name: tool.function.name,
      description: tool.function.description,
      inputSchema: _toInputSchema(tool.function.parameters),
      strict: tool.function.strict,
    ),
  );
}

anthropic.InputSchema _toInputSchema(Map<String, dynamic>? parameters) {
  final schema = parameters ?? const <String, dynamic>{};
  final properties = schema['properties'];
  final required = schema['required'];
  // 其余 JSON Schema 关键字（type / additionalProperties / $schema…）由
  // `extra` 平铺回顶层，不能让工具声明在转换中丢字段。
  final extra = <String, dynamic>{
    for (final entry in schema.entries)
      if (entry.key != 'properties' && entry.key != 'required')
        entry.key: entry.value,
  };
  return anthropic.InputSchema(
    properties: properties is Map ? Map<String, dynamic>.from(properties) : null,
    required: required is List ? required.cast<String>() : null,
    extra: extra,
  );
}

Map<String, dynamic> _decodeArguments(String arguments) {
  if (arguments.trim().isEmpty) return const <String, dynamic>{};
  try {
    final decoded = jsonDecode(arguments);
    return decoded is Map<String, dynamic>
        ? decoded : const <String, dynamic>{};
  } on FormatException {
    // 上游给的参数半截、非 JSON 或非对象：下发空对象，让模型重新发起调用，
    // 而不是把整轮对话打挂。
    return const <String, dynamic>{};
  }
}

FinishReason? _finishReason(anthropic.StopReason? stopReason) {
  return switch (stopReason) {
    null => null,
    anthropic.StopReason.toolUse => FinishReason.toolCalls,
    anthropic.StopReason.maxTokens ||
    anthropic.StopReason.modelContextWindowExceeded => FinishReason.length,
    anthropic.StopReason.refusal => FinishReason.contentFilter,
    anthropic.StopReason.endTurn ||
    anthropic.StopReason.stopSequence => FinishReason.stop,
    // Athena 尚未请求服务端工具或服务端压缩，不能假装已完成这些回合。
    _ => throw UnsupportedError('Messages continuation is not supported: ${stopReason.value}'),
  };
}

Usage _usage({
  required int inputTokens,
  required int outputTokens,
  required int cachedTokens,
  required int cacheCreationTokens,
  int? reasoningTokens,
}) {
  final totalInput = inputTokens + cachedTokens + cacheCreationTokens;
  return CacheUsage(
    cacheCreationTokens: cacheCreationTokens,
    promptTokens: totalInput,
    completionTokens: outputTokens,
    totalTokens: totalInput + outputTokens,
    promptTokensDetails: PromptTokensDetails(cachedTokens: cachedTokens),
    completionTokensDetails: reasoningTokens == null
        ? null : CompletionTokensDetails(reasoningTokens: reasoningTokens),
  );
}

ChatStreamEvent _chunk(ChatDelta delta) {
  return ChatStreamEvent(
    object: 'chat.completion.chunk',
    choices: [ChatStreamChoice(index: 0, delta: delta)],
  );
}

ChatStreamEvent _terminalChunk({
  required String? id,
  required String? model,
  required FinishReason? finishReason,
  required Usage usage,
}) {
  return ChatStreamEvent(
    id: id,
    object: 'chat.completion.chunk',
    model: model,
    choices: [
      ChatStreamChoice(
        index: 0,
        delta: const ChatDelta(),
        finishReason: finishReason,
      ),
    ],
    usage: usage,
  );
}

anthropic.ToolChoice? _messageToolChoice(ToolChoice? choice, bool? parallel) {
  final disable = parallel == null ? null : !parallel;
  return switch (choice) {
    null => parallel == null ? null
        : anthropic.ToolChoice.auto(disableParallelToolUse: disable),
    ToolChoiceAuto() => anthropic.ToolChoice.auto(disableParallelToolUse: disable),
    ToolChoiceNone() => anthropic.ToolChoice.none(),
    ToolChoiceRequired() => anthropic.ToolChoice.any(disableParallelToolUse: disable),
    ToolChoiceFunction(:final name) =>
      anthropic.ToolChoice.tool(name, disableParallelToolUse: disable),
    _ => throw UnsupportedError('Messages does not support ${choice.runtimeType}'),
  };
}
