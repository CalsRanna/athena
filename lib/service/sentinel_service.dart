import 'dart:convert';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:openai_dart/openai_dart.dart';

/// SentinelService 负责 Sentinel 生成相关的网络请求
class SentinelService {
  /// 仅生成 Sentinel 名称
  Future<String> generateName(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    final sentinel = await _generateWithPrompt(
      prompt: prompt,
      systemPrompt: PresetPrompt.nameGenerationPrompt,
      provider: provider,
      model: model,
    );
    return sentinel.name;
  }

  /// 仅生成 Sentinel 描述，可传入已有名称作为上下文
  Future<String> generateDescription(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
    String existingName = '',
  }) async {
    final userContent = existingName.isNotEmpty
        ? '已有名称: $existingName\n$prompt'
        : prompt;
    final sentinel = await _generateWithPrompt(
      prompt: userContent,
      systemPrompt: PresetPrompt.descriptionGenerationPrompt,
      provider: provider,
      model: model,
    );
    return sentinel.description;
  }

  /// 内部通用方法：使用指定的 system prompt 调用 LLM 生成
  Future<SentinelEntity> _generateWithPrompt({
    required String prompt,
    required String systemPrompt,
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
    try {
      var messages = [
        ChatMessage.system(systemPrompt),
        ChatMessage.user(prompt),
      ];
      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: messages,
      );
      var response = await client.chat.completions.create(request);
      final content = response.text ?? '';
      final formatted = jsonDecode(
        content.replaceAll('```json', '').replaceAll('```', ''),
      );
      return SentinelEntity(
        name: formatted['name'] ?? '',
        description: formatted['description'] ?? '',
        tags: '',
        avatar: '',
        prompt: prompt,
      );
    } finally {
      client.close();
    }
  }

  /// 基于用户输入的 prompt 生成完整 Sentinel 元数据（名称、描述、标签、头像）
  Future<SentinelEntity> generate(
    String prompt, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    return _generateWithPrompt(
      prompt: prompt,
      systemPrompt: PresetPrompt.metadataGenerationPrompt,
      provider: provider,
      model: model,
    );
  }
}
