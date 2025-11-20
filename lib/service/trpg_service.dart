import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/model/action_suggestion.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/vendor/enhanced_openai_dart/client.dart';
import 'package:athena/vendor/enhanced_openai_dart/response.dart';
import 'package:openai_dart/openai_dart.dart';

class TRPGService {
  /// 获取 DM 响应流
  Stream<EnhancedCreateChatCompletionStreamResponse> getDMResponse({
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
    yield* client.createOverrodeChatCompletionStream(request: request);
  }

  /// 生成行动建议
  Future<List<ActionSuggestion>> generateSuggestions({
    required String dmMessage,
    required String characterProfile,
    required int currentHP,
    required int maxHP,
    required int currentMP,
    required int maxMP,
    required String inventory,
    required String currentQuest,
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

      var prompt = PresetPrompt.actionSuggestionPrompt
          .replaceAll('{dm_message}', dmMessage)
          .replaceAll('{character_profile}', characterProfile)
          .replaceAll('{current_hp}', currentHP.toString())
          .replaceAll('{max_hp}', maxHP.toString())
          .replaceAll('{current_mp}', currentMP.toString())
          .replaceAll('{max_mp}', maxMP.toString())
          .replaceAll('{inventory}', inventory)
          .replaceAll('{current_quest}', currentQuest);

      var messages = [
        ChatCompletionMessage.system(content: prompt),
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(
            '请为当前场景生成行动建议',
          ),
        ),
      ];

      var request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(model.modelId),
        messages: messages,
        temperature: 0.8,
      );

      var response = await client.createChatCompletion(request: request);
      var content = response.choices.first.message.content ?? '';

      // 清理 markdown 代码块标记
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      var json = jsonDecode(content);
      var suggestionsJson = json['suggestions'] as List;
      return suggestionsJson
          .map((s) => ActionSuggestion.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (error) {
      // 生成失败时静默返回空列表
      return [];
    }
  }

  /// 解析 HUD 状态信息
  Map<String, dynamic> parseStatus(String response) {
    var result = <String, dynamic>{};

    // 解析 HP
    var hpMatch = RegExp(r'HP.*?(\d+)/(\d+)').firstMatch(response);
    if (hpMatch != null) {
      result['current_hp'] = int.parse(hpMatch.group(1) ?? '100');
      result['max_hp'] = int.parse(hpMatch.group(2) ?? '100');
    }

    // 解析 MP
    var mpMatch = RegExp(r'MP.*?(\d+)/(\d+)').firstMatch(response);
    if (mpMatch != null) {
      result['current_mp'] = int.parse(mpMatch.group(1) ?? '50');
      result['max_mp'] = int.parse(mpMatch.group(2) ?? '50');
    }

    // 解析 Inventory
    var inventoryMatch =
        RegExp(r'Inventory.*?:(.*?)(?:\n|$)', multiLine: true)
            .firstMatch(response);
    if (inventoryMatch != null) {
      result['inventory'] = inventoryMatch.group(1)?.trim() ?? '';
    }

    // 解析 Active Quest
    var questMatch = RegExp(r'Active Quest.*?:(.*?)(?:\n|$)', multiLine: true)
        .firstMatch(response);
    if (questMatch != null) {
      result['current_quest'] = questMatch.group(1)?.trim() ?? '';
    }

    // 解析场景信息
    var sceneMatch = RegExp(r'\[🌐 场景：(.*?)\|').firstMatch(response);
    if (sceneMatch != null) {
      result['current_scene'] = sceneMatch.group(1)?.trim() ?? '';
    }

    return result;
  }
}
