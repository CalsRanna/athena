import 'dart:convert';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/completion_details.dart';
import 'package:crypto/crypto.dart';
import 'package:openai_dart/openai_dart.dart';

/// 兼容端的 reasoning_details 可能含签名或密文，只回传给原始来源。
class ChatCompletionsState {
  final Map<String, dynamic> _data;
  ChatCompletionsState(
    ProviderEntity provider,
    String model,
    AssistantMessage original,
    AssistantMessage visible, {
    int reasoningTokens = 0,
  }) : _data = {
         'version': 1,
         'provider_id': provider.id,
         'base_url': _url(provider.baseUrl),
         'model': model,
         'reasoning_tokens': reasoningTokens,
         'message': original.toJson(),
         'message_hash': _hash(visible),
       };
  ChatCompletionsState._(this._data);

  int get reasoningTokens => _data['reasoning_tokens'] as int? ?? 0;
  String encode() => jsonEncode(_data);
  static ChatCompletionsState? decode(String value) {
    if (value.isEmpty) return null;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          data['base_url'] is! String ||
          data['model'] is! String ||
          (data['reasoning_tokens'] != null &&
              (data['reasoning_tokens'] is! int ||
                  (data['reasoning_tokens'] as int) < 0)) ||
          data['message_hash'] is! String ||
          ChatMessage.fromJson(data['message'] as Map<String, dynamic>)
              is! AssistantMessage) {
        return null;
      }
      return ChatCompletionsState._(data);
    } catch (_) {
      return null;
    }
  }

  AssistantMessage get message =>
      ChatMessage.fromJson(_data['message'] as Map<String, dynamic>)
          as AssistantMessage;

  bool matches(
    ProviderEntity provider,
    String model,
    AssistantMessage visible,
  ) =>
      provider.apiFormat == ApiFormat.chatCompletions &&
      provider.id == _data['provider_id'] &&
      _url(provider.baseUrl) == _data['base_url'] &&
      model == _data['model'] &&
      matchesMessage(visible);

  bool matchesMessage(AssistantMessage visible) =>
      _hash(visible) == _data['message_hash'];
  static String _url(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');
  static String _hash(AssistantMessage message) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'content': message.content ?? '',
            'tool_calls':
                message.toolCalls?.map((c) => c.toJson()).toList() ?? [],
          }),
        ),
      )
      .toString();
}

class ChatCompletionsAssistantMessage extends AssistantMessage {
  final ChatCompletionsState? chatCompletionsState;
  const ChatCompletionsAssistantMessage({
    this.chatCompletionsState,
    super.content,
    super.toolCalls,
    super.reasoningContent,
    super.refusal,
  });
}

class ChatCompletionsStateChunk extends ChatStreamEvent {
  final ChatCompletionsState state;
  const ChatCompletionsStateChunk(this.state);
}

ChatCompletionCreateRequest restoreChatCompletionsRequest(
  ChatCompletionCreateRequest request,
  ProviderEntity provider,
) => request.copyWith(
  messages: [
    for (final message in request.messages)
      if (message is ChatCompletionsAssistantMessage &&
          message.chatCompletionsState?.matches(
                provider,
                request.model,
                message,
              ) ==
              true)
        message.chatCompletionsState!.message
      else
        message,
  ],
);

AssistantMessage _visibleMessage(AssistantMessage original) => AssistantMessage(
  content: '${original.content ?? ''}${original.refusal ?? ''}',
  toolCalls: original.toolCalls,
  reasoningContent: _visibleReasoning(original),
);

String? _visibleReasoning(AssistantMessage message) {
  final text = _ReasoningDisplay().add(
    ChatDelta(
      reasoningContent: message.reasoningContent,
      reasoning: message.reasoning,
      reasoningDetails: message.reasoningDetails,
    ),
  );
  return text.isEmpty ? null : text;
}

// 同一供应商可能同时发送旧字段和 details。选择最先出现的可读通道，
// 同包时优先旧字段，避免两个通道的相同文字在界面重复；原始数据另存。
class _ReasoningDisplay {
  String? _source;
  Object? _lastPart;

  String add(ChatDelta delta) {
    if (_source == null) {
      if (delta.reasoningContent?.isNotEmpty == true) {
        _source = 'content';
      } else if (delta.reasoning?.isNotEmpty == true) {
        _source = 'reasoning';
      } else if (delta.reasoningDetails?.any(
            (d) =>
                (d.isSummary && d.summary?.isNotEmpty == true) ||
                (d.isText && d.text?.isNotEmpty == true),
          ) ==
          true) {
        _source = 'details';
      }
    }
    if (_source == 'content') return delta.reasoningContent ?? '';
    if (_source == 'reasoning') return delta.reasoning ?? '';
    if (_source != 'details') return '';
    final text = StringBuffer();
    for (final detail in delta.reasoningDetails ?? <ReasoningDetail>[]) {
      final part = detail.isSummary
          ? detail.summary
          : detail.isText
          ? detail.text
          : null;
      if (part == null || part.isEmpty) continue;
      final key = (detail.type, detail.index ?? detail.id);
      if (_lastPart != null && _lastPart != key) text.write('\n\n');
      _lastPart = key;
      text.write(part);
    }
    return text.toString();
  }
}

/// 拒答也进入文本事件；原始字段另存，避免回传时重复正文或丢失拒答语义。
Stream<ChatStreamEvent> normalizeChatCompletionsStream(
  Stream<ChatStreamEvent> events,
  ProviderEntity provider,
  String model,
) async* {
  final raw = ChatStreamAccumulator();
  final displays = <int, _ReasoningDisplay>{};
  await for (final event in events) {
    raw.add(event);
    yield ChatStreamEvent.fromJson({
      ...event.toJson(),
      if (event.choices != null)
        'choices': [
          for (final choice in event.choices!)
            {
              ...choice.toJson(),
              'delta': {
                ...choice.delta.toJson(),
                'reasoning': null,
                'reasoning_content': displays
                    .putIfAbsent(choice.index ?? 0, _ReasoningDisplay.new)
                    .add(choice.delta),
              },
            },
        ],
    });
    final refusal = event.firstChoice?.delta.refusal;
    if (refusal != null && refusal.isNotEmpty) {
      yield ChatStreamEvent(
        choices: [
          ChatStreamChoice(index: 0, delta: ChatDelta(content: refusal)),
        ],
      );
    }
  }
  if (raw.finishReason == null) {
    throw StateError('Chat Completions stream ended before finish_reason');
  }
  yield CompletionDetailsChunk({
    'protocol': 'chat_completions',
    'finish_reason': raw.finishReason!.value,
    if (raw.refusal.isNotEmpty) 'refusal': raw.refusal,
    if (raw.usage != null) 'usage': raw.usage!.toJson(),
  });
  if (raw.finishReason == FinishReason.stop ||
      raw.finishReason == FinishReason.toolCalls) {
    final original = raw.toChatCompletion().choices.first.message;
    yield ChatCompletionsStateChunk(
      ChatCompletionsState(
        provider,
        model,
        original,
        _visibleMessage(original),
        reasoningTokens:
            raw.usage?.completionTokensDetails?.reasoningTokens ?? 0,
      ),
    );
  }
}

ChatCompletion normalizeChatCompletion(
  ChatCompletion response,
  ProviderEntity provider,
  String model,
) => DetailedChatCompletion(
  id: response.id,
  object: response.object,
  created: response.created,
  model: response.model,
  usage: response.usage,
  systemFingerprint: response.systemFingerprint,
  serviceTier: response.serviceTier,
  moderation: response.moderation,
  provider: response.provider,
  details: {
    'protocol': 'chat_completions',
    'finish_reason': response.choices.firstOrNull?.finishReason?.value,
    if (response.choices.firstOrNull?.message.refusal case final String refusal)
      'refusal': refusal,
    if (response.usage != null) 'usage': response.usage!.toJson(),
  },
  choices: [
    for (final choice in response.choices)
      ChatChoice(
        index: choice.index,
        finishReason: choice.finishReason,
        logprobs: choice.logprobs,
        message: ChatCompletionsAssistantMessage(
          content: choice.message.content,
          reasoningContent: _visibleReasoning(choice.message),
          refusal: choice.message.refusal,
          toolCalls: choice.message.toolCalls,
          chatCompletionsState:
              choice.finishReason == FinishReason.stop ||
                  choice.finishReason == FinishReason.toolCalls
              ? ChatCompletionsState(
                  provider,
                  model,
                  choice.message,
                  choice.message,
                  reasoningTokens:
                      response
                          .usage
                          ?.completionTokensDetails
                          ?.reasoningTokens ??
                      0,
                )
              : null,
        ),
      ),
  ],
);
