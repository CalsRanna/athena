import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';

/// 聊天相关的 AI 网络请求。
///
/// 在 [LlmClient] 之上提供 chat 特有的默认值（如 StreamOptions、temperature）。
/// 不涉及消息格式转换（→ [ChatMessageService]）、
/// 会话/消息持久化（→ [ChatManageService]）、
/// 或 UI 辅助操作（→ [ChatSupportService]）。
class ChatService {
  final LlmClient _llmClient;

  ChatService({
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
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: chat.temperature,
      tools: tools,
      streamOptions: const StreamOptions(includeUsage: true),
    );
    yield* _llmClient.stream(provider: provider, request: request);
  }

  /// 非流式完成，用于辅助模型摘要等场景
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
    );
    var response = await _llmClient.fetch(
      provider: provider,
      request: request,
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
