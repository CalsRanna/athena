import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/vendor/enhanced_openai_dart/client.dart';
import 'package:athena/vendor/enhanced_openai_dart/delta.dart';
import 'package:openai_dart/openai_dart.dart';

class TRPGService {
  Future<List<String>> getSuggestions({
    required String dmMessage,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    try {
      var headers = {
        'HTTP-Referer': 'https://github.com/CalsRanna/athena',
        'X-Title': 'Athena',
      };
      var client = OpenAIClient(
        apiKey: provider.apiKey,
        baseUrl: provider.baseUrl,
        headers: headers,
      );

      var messages = [
        ChatCompletionMessage.system(
          content: PresetPrompt.actionSuggestionPrompt,
        ),
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(dmMessage),
        ),
      ];

      var request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(model.modelId),
        messages: messages,
        temperature: 0.8,
      );

      var response = await client.createChatCompletion(request: request);
      var content = response.choices.first.message.content ?? '';

      // 清理可能的 markdown 代码块标记
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      // 解析 JSON 数组
      try {
        var jsonArray = jsonDecode(content) as List;
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

  Stream<EnhancedStreamResponse> getDMResponse({
    required List<ChatCompletionMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    double temperature = 1.0,
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
      temperature: temperature,
    );
    yield* client.createEnhancedChatCompletionStream(request: request);
  }
}
