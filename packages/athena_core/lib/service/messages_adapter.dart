import 'dart:async';
import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:openai_dart/openai_dart.dart';

/// Messages（Anthropic）与 Chat Completions 形状之间的转换。
///
/// 与 `responses_adapter.dart` 同一套路：Athena 上层（`AgentService`、
/// `ChatStreamAccumulator`、`ChatMessageConverter`）按 Chat Completions 形状
/// 工作，接 Messages 时只在适配器里做双向映射。上层零改动。
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
/// 取与 `ContextBudget` 给输出预留的上限一致的值，避免默认过小把回复截断。
const _defaultMaxTokens = 8192;

/// 把 Chat Completions 形状的请求转成 Messages 请求。
anthropic.MessageCreateRequest toMessageRequest(
  ChatCompletionCreateRequest request, {
  bool stream = false,
}) {
  // Messages 没有 JSON 输出格式对应的参数（Responses 至少能表达 json_object）。
  // 不显式失败的话，`/json` 模式下会静默按普通对话发出，用户拿到的是
  // 「看起来生效但其实没有」的结果。
  if (request.responseFormat != null) {
    throw UnsupportedError(
      'Messages 协议暂不支持 ${request.responseFormat.runtimeType} 形式的 '
      'response_format',
    );
  }

  final system = <String>[];
  final messages = <anthropic.InputMessage>[];
  final pending = <anthropic.InputContentBlock>[];
  _Role pendingRole = _Role.none;

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
      case SystemMessage(:final content):
        // Anthropic 不接受 messages 里的 system：统一上提到顶层。
        if (content.isNotEmpty) system.add(content);
      case DeveloperMessage(:final content):
        if (content.isNotEmpty) system.add(content);
      case UserMessage(:final content):
        push(_Role.user, _toUserBlocks(content));
      case AssistantMessage(:final content, :final toolCalls):
        final blocks = <anthropic.InputContentBlock>[
          if (content != null && content.isNotEmpty)
            anthropic.InputContentBlock.text(content),
          for (final call in toolCalls ?? const <ToolCall>[])
            anthropic.InputContentBlock.toolUse(
              id: call.id,
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
            toolUseId: toolCallId,
            text: content,
          ),
        ]);
    }
  }
  flush();

  return anthropic.MessageCreateRequest(
    model: request.model,
    maxTokens: _defaultMaxTokens,
    system: system.isEmpty ? null : anthropic.SystemPrompt.text(system.join('\n\n')),
    messages: messages,
    tools: request.tools?.map(_toToolDefinition).toList(),
    temperature: request.temperature,
    stream: stream,
  );
}

/// 把 Messages 的流式事件归一成 Chat Completions 形状的流。
Stream<ChatStreamEvent> normalizeMessagesStream(
  Stream<anthropic.MessageStreamEvent> events,
) async* {
  // content block 下标 → toolCalls 下标：文本块也占下标，而
  // ChatStreamAccumulator 把 index 当列表下标用，必须重编号。
  final callIndexes = <int, int>{};
  // input / 缓存用量只在 message_start 给，output 用量在 message_delta 给。
  var inputTokens = 0;
  var cachedTokens = 0;
  String? id;
  String? model;

  await for (final event in events) {
    switch (event) {
      case anthropic.MessageStartEvent(:final message):
        id = message.id;
        model = message.model;
        inputTokens = message.usage.inputTokens;
        cachedTokens = message.usage.cacheReadInputTokens ?? 0;

      case anthropic.ContentBlockStartEvent(:final index, :final contentBlock):
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
                  function: FunctionCallDelta(name: contentBlock.name),
                ),
              ],
            ),
          );
        }

      case anthropic.ContentBlockDeltaEvent(:final index, :final delta):
        switch (delta) {
          case anthropic.TextDelta(:final text):
            if (text.isNotEmpty) yield _chunk(ChatDelta(content: text));
          case anthropic.ThinkingDelta(:final thinking):
            if (thinking.isNotEmpty) {
              yield _chunk(ChatDelta(reasoning: thinking));
            }
          case anthropic.InputJsonDelta(:final partialJson):
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

      case anthropic.MessageDeltaEvent(:final delta, :final usage):
        yield _terminalChunk(
          id: id,
          model: model,
          finishReason: _finishReason(delta.stopReason),
          usage: _usage(
            inputTokens: usage.inputTokens ?? inputTokens,
            outputTokens: usage.outputTokens,
            cachedTokens: usage.cacheReadInputTokens ?? cachedTokens,
          ),
        );

      case anthropic.ErrorEvent():
        throw StateError('Messages 请求失败：${event.errorType} ${event.message}');

      default:
        break;
    }
  }
}

/// 把 Messages 的完整响应转成 Chat Completion（非流式路径）。
ChatCompletion messageToChatCompletion(anthropic.Message message) {
  final text = [
    for (final block in message.content)
      if (block is anthropic.TextBlock) block.text,
  ].join();
  return ChatCompletion(
    id: message.id,
    object: 'chat.completion',
    model: message.model,
    choices: [
      ChatChoice(
        index: 0,
        message: AssistantMessage(content: text),
        finishReason: _finishReason(message.stopReason),
      ),
    ],
    usage: _usage(
      inputTokens: message.usage.inputTokens,
      outputTokens: message.usage.outputTokens,
      cachedTokens: message.usage.cacheReadInputTokens ?? 0,
    ),
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
    return Map<String, dynamic>.from(jsonDecode(arguments) as Map);
  } on FormatException {
    // 上游给的参数半截或非 JSON：下发空对象，让模型重新发起调用，
    // 而不是把整轮对话打挂。
    return const <String, dynamic>{};
  }
}

FinishReason _finishReason(anthropic.StopReason? stopReason) {
  return switch (stopReason) {
    anthropic.StopReason.toolUse => FinishReason.toolCalls,
    // 归一到 length：上层据此拒绝执行被截断的 tool_calls。
    anthropic.StopReason.maxTokens => FinishReason.length,
    _ => FinishReason.stop,
  };
}

Usage _usage({
  required int inputTokens,
  required int outputTokens,
  required int cachedTokens,
}) {
  return Usage(
    promptTokens: inputTokens,
    completionTokens: outputTokens,
    totalTokens: inputTokens + outputTokens,
    promptTokensDetails: PromptTokensDetails(cachedTokens: cachedTokens),
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
  required FinishReason finishReason,
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
