import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/preset/prompt.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

/// 聊天相关的 AI 网络请求。
///
/// 在 [LlmClient] 之上提供 chat 特有的默认值（如 StreamOptions、temperature）。
/// 不涉及消息格式转换（→ [ChatMessageConverter]）、
/// 会话/消息持久化（→ [ChatStoreService]）、
/// 或 UI 辅助操作（→ [ChatUpdateService]）。
class ChatCompletionsService {
  final LlmClient _llmClient;

  ChatCompletionsService({
    required LlmClient llmClient,
  }) : _llmClient = llmClient;

  /// 测试连接
  Future<String> connect({
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [ChatMessage.user('Hi')],
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
    );
    return response.text ?? '';
  }

  /// 获取聊天完成流
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: chat.temperature,
      reasoningEffort: _parseReasoningEffort(chat.reasoningEffort),
      tools: tools,
      responseFormat: responseFormat,
      streamOptions: const StreamOptions(includeUsage: true),
    );
    yield* _llmClient.stream(
      provider: provider,
      request: request,
      cancelSignal: cancelSignal,
    );
  }

  /// 非流式完成，用于辅助模型摘要等场景
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
      cancelSignal: cancelSignal,
    );
    return response.text ?? '';
  }

  /// 获取聊天标题流
  Stream<String> getTitle(
    String value, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: [
        ChatMessage.system(PresetPrompt.namingPrompt),
        ChatMessage.user(value),
      ],
    );
    var stream = _llmClient.stream(provider: provider, request: request);
    await for (final chunk in stream) {
      if (chunk.choices == null || chunk.choices!.isEmpty) continue;
      yield chunk.choices!.first.delta.content ?? '';
    }
  }
}

/// 解析会话存储的推理强度字符串为官方枚举；非法/未识别值返回 null
/// （不传参，交由模型决定），避免把 unknown 发送到 API。
ReasoningEffort? _parseReasoningEffort(String? value) {
  if (value == null) return null;
  final parsed = ReasoningEffort.fromJson(value);
  return parsed == ReasoningEffort.unknown ? null : parsed;
}
