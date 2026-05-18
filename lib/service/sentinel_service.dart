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
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var system = PresetPrompt.metadataGenerationPrompt;
    var messages = [
      MessageEntity(chatId: 0, role: 'system', content: system),
      MessageEntity(chatId: 0, role: 'user', content: prompt),
    ];
    var wrappedMessages = messages.map((message) {
      if (message.role == 'system') {
        return ChatMessage.system(message.content);
      } else if (message.role == 'assistant') {
        return ChatMessage.assistant(content: message.content);
      } else {
        return ChatMessage.user(message.content);
      }
    }).toList();
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: wrappedMessages,
    );
    var response = await client.chat.completions.create(request);
    final content = response.text ?? '';
    final formatted = jsonDecode(
      content.replaceAll('```json', '').replaceAll('```', ''),
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
