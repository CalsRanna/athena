import 'dart:convert';

import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:openai_dart/openai_dart.dart';

/// SentinelService 负责 Sentinel 生成相关的网络请求
class SentinelService {
  /// 基于用户输入的 prompt 生成 Sentinel 元数据
  Future<SentinelEntity> generate(
    String prompt, {
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
    var system = PresetPrompt.metadataGenerationPrompt;
    var messages = [
      MessageEntity(chatId: 0, role: 'system', content: system),
      MessageEntity(chatId: 0, role: 'user', content: prompt),
    ];
    var wrappedMessages = messages.map((message) {
      if (message.role == 'system') {
        return ChatCompletionMessage.system(content: message.content);
      } else if (message.role == 'assistant') {
        return ChatCompletionMessage.assistant(content: message.content);
      } else {
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message.content),
        );
      }
    }).toList();
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: wrappedMessages,
    );
    var response = await client.createChatCompletion(request: request);
    final content = response.choices.first.message.content;
    final formatted = jsonDecode(
      content.toString().replaceAll('```json', '').replaceAll('```', ''),
    );
    final tagsList = List<String>.from(formatted['tags'] ?? []);
    return SentinelEntity(
      name: formatted['name'] ?? '',
      description: formatted['description'] ?? '',
      tags: tagsList.join(', '),
      avatar: formatted['avatar'] ?? '',
      prompt: prompt,
    );
  }
}
