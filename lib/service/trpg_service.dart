import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:openai_dart/openai_dart.dart';

class TRPGService {
  Future<List<String>> getSuggestions({
    required String dmMessage,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    try {
      var client = OpenAIClient.withApiKey(
        provider.apiKey,
        baseUrl: provider.baseUrl,
        defaultHeaders: {
          'HTTP-Referer': 'https://github.com/CalsRanna/athena',
          'X-Title': 'Athena',
        },
      );

      var request = ChatCompletionCreateRequest(
        model: model.modelId,
        messages: [
          ChatMessage.system(PresetPrompt.actionSuggestionPrompt),
          ChatMessage.user(dmMessage),
        ],
        temperature: 0.8,
      );

      var response = await client.chat.completions.create(request);
      var content = response.text ?? '';

      // 清理可能的 markdown 代码块标记
      content = content
          .replaceAll(RegExp(r'```\w*\n?'), '')
          .replaceAll('```', '')
          .trim();

      // 提取 JSON 数组（处理模型可能输出额外文本的情况）
      var jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
      if (jsonMatch == null) return [];

      // 解析 JSON 数组
      try {
        var jsonArray = jsonDecode(jsonMatch.group(0)!) as List;
        return jsonArray.map((item) => item.toString()).toList();
      } catch (e) {
        // 如果 JSON 解析失败，返回空列表
        return [];
      }
    } catch (error) {
      // 生成失败时静默返回空列表
      return [];
    }
  }

  Stream<ChatStreamEvent> getDMResponse({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    double temperature = 1.0,
  }) async* {
    var client = OpenAIClient.withApiKey(
      provider.apiKey,
      baseUrl: provider.baseUrl,
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      },
    );
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
      temperature: temperature,
    );
    yield* client.chat.completions.createStream(request);
  }
}
