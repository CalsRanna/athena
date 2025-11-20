import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/model/search_decision.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/vendor/enhanced_openai_dart/client.dart';
import 'package:athena/vendor/enhanced_openai_dart/response.dart';
import 'package:openai_dart/openai_dart.dart';

/// ChatService 负责与 AI 提供商进行聊天相关的网络请求
class ChatService {
  /// 测试连接
  Future<String> connect({
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var message = ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('Hi'),
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: [message],
    );
    var response = await client.createChatCompletion(request: request);
    return response.choices.first.message.content ?? '';
  }

  /// 获取聊天完成流
  Stream<EnhancedCreateChatCompletionStreamResponse> getCompletion({
    required ChatEntity chat,
    required List<ChatCompletionMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = EnhancedOpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: messages,
      temperature: chat.temperature,
    );
    yield* client.createOverrodeChatCompletionStream(request: request);
  }

  /// 获取搜索决策
  Future<SearchDecision> getSearchDecision(
    String message, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var now = DateTime.now();
    var prompt = PresetPrompt.searchDecisionPrompt.replaceAll(
      '{now}',
      now.toString(),
    );
    var wrappedMessages = [
      ChatCompletionMessage.system(content: prompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(message),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: wrappedMessages,
    );
    var response = await client.createChatCompletion(request: request);
    var content = response.choices.first.message.content ?? '';
    content = content.replaceAll('```json', '').replaceAll('```', '');
    try {
      var json = jsonDecode(content);
      return SearchDecision.fromJson(json);
    } catch (error) {
      return SearchDecision();
    }
  }

  /// 获取聊天标题流
  Stream<String> getTitle(
    String value, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var wrappedMessages = [
      ChatCompletionMessage.system(content: PresetPrompt.namingPrompt),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(value),
      ),
    ];
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: wrappedMessages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta.content ?? '';
    }
  }
}
