import 'dart:async';

import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/trpg_game_entity.dart';
import 'package:athena/entity/trpg_message_entity.dart';
import 'package:athena/preset/prompt.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/trpg_game_repository.dart';
import 'package:athena/repository/trpg_message_repository.dart';
import 'package:athena/service/trpg_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

class TRPGViewModel {
  // Repositories
  final TRPGGameRepository _gameRepository = TRPGGameRepository();
  final TRPGMessageRepository _messageRepository = TRPGMessageRepository();
  final ModelRepository _modelRepository = ModelRepository();
  final ProviderRepository _providerRepository = ProviderRepository();

  // Service
  final TRPGService _service = TRPGService();

  // Signals
  final currentGame = signal<TRPGGameEntity?>(null);
  final messages = listSignal<TRPGMessageEntity>([]);
  final isStreaming = signal(false);
  final isGeneratingSuggestions = signal(false);
  final currentHP = signal(100);
  final maxHP = signal(100);
  final currentMP = signal(50);
  final maxMP = signal(50);
  final inventory = listSignal<String>([]);
  final currentQuest = signal('');
  final currentScene = signal('');
  final currentSuggestions = listSignal<String>([]); // 当前显示的建议列表
  final error = signal<String?>(null);

  // 当前流式响应的消息实体
  final streamingMessage = signal<TRPGMessageEntity?>(null);

  /// 创建新游戏
  Future<TRPGGameEntity?> createNewGame({
    required String gameStyle,
    required String characterClass,
    required String gameMode,
  }) async {
    try {
      // 获取默认模型
      var model = await _getDefaultModel();
      if (model == null) {
        error.value = '未找到可用的模型';
        return null;
      }

      // 创建游戏实体
      var now = DateTime.now();
      var game = TRPGGameEntity(
        title: '$gameStyle - $characterClass',
        gameStyle: gameStyle,
        characterClass: characterClass,
        gameMode: gameMode,
        modelId: model.id!,
        createdAt: now,
        updatedAt: now,
      );

      var gameId = await _gameRepository.createGame(game);
      game = game.copyWith(id: gameId);
      currentGame.value = game;

      // 初始化状态
      currentHP.value = 100;
      maxHP.value = 100;
      currentMP.value = 50;
      maxMP.value = 50;
      inventory.value = [];
      currentQuest.value = '';
      currentScene.value = '';
      messages.value = [];

      // 发送初始化消息
      var initMessage =
          '''
1. 剧本风格：$gameStyle
2. 角色设定：$characterClass
3. 游戏基调：$gameMode

请开始游戏！
''';

      await sendPlayerAction(initMessage);
      return game;
    } catch (e) {
      error.value = '创建游戏失败：$e';
      return null;
    }
  }

  /// 删除游戏
  Future<void> deleteGame(int gameId) async {
    try {
      await _gameRepository.deleteGame(gameId);
      if (currentGame.value?.id == gameId) {
        currentGame.value = null;
        messages.value = [];
      }
    } catch (e) {
      error.value = '删除游戏失败：$e';
    }
  }

  /// 删除消息（用于重试）
  Future<void> deleteMessage(TRPGMessageEntity message) async {
    try {
      if (message.id != null) {
        await _messageRepository.deleteMessage(message.id!);
      }
      messages.remove(message);
      // 删除该消息后的所有消息
      var messageIndex = messages.value.indexOf(message);
      if (messageIndex >= 0) {
        var toRemove = messages.value.skip(messageIndex).toList();
        for (var msg in toRemove) {
          if (msg.id != null) {
            await _messageRepository.deleteMessage(msg.id!);
          }
        }
        messages.value = messages.value.take(messageIndex).toList();
      }
    } catch (e) {
      error.value = '删除消息失败：$e';
    }
  }

  /// 加载游戏存档
  Future<void> loadGame(int gameId) async {
    try {
      var game = await _gameRepository.getGameById(gameId);
      if (game == null) {
        error.value = '游戏不存在';
        return;
      }

      currentGame.value = game;

      // 加载游戏状态
      currentHP.value = game.currentHP;
      maxHP.value = game.maxHP;
      currentMP.value = game.currentMP;
      maxMP.value = game.maxMP;
      currentQuest.value = game.currentQuest;
      currentScene.value = game.currentScene;

      // 解析背包
      if (game.inventory.isNotEmpty) {
        inventory.value = game.inventory
            .split(',')
            .map((e) => e.trim())
            .toList();
      } else {
        inventory.value = [];
      }

      // 加载消息历史
      var loadedMessages = await _messageRepository.getMessagesByGameId(gameId);
      messages.value = loadedMessages;
    } catch (e) {
      error.value = '加载游戏失败：$e';
    }
  }

  /// 发送玩家行动
  Future<void> sendPlayerAction(String action) async {
    var game = currentGame.value;
    if (game == null) return;

    try {
      // 清空当前的建议
      currentSuggestions.value = [];

      // 创建玩家消息
      var playerMessage = TRPGMessageEntity(
        gameId: game.id!,
        role: 'player',
        content: action,
        createdAt: DateTime.now(),
      );
      await _messageRepository.createMessage(playerMessage);
      messages.add(playerMessage);

      // 构建对话历史
      var chatMessages = await _buildChatMessages();

      // 获取提供商和模型
      var model = await _modelRepository.getModelById(game.modelId);
      if (model == null) return;

      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) return;

      // 流式获取 DM 响应
      isStreaming.value = true;

      // 初始化 streaming message
      streamingMessage.value = TRPGMessageEntity(
        gameId: game.id!,
        role: 'dm',
        content: '',
        createdAt: DateTime.now(),
      );

      var stream = _service.getDMResponse(
        messages: chatMessages,
        provider: provider,
        model: model,
      );

      var fullContent = '';
      await for (var chunk in stream) {
        var delta = chunk.response.choices.first.delta.content ?? '';
        fullContent += delta;
        streamingMessage.value = streamingMessage.value!.copyWith(
          content: fullContent,
        );
      }

      // 生成行动建议（此时仍然保持 streaming 状态）
      var suggestions = await _generateActionSuggestions(
        dmMessage: fullContent,
        model: model,
        provider: provider,
      );

      // 保存 DM 消息（带 suggestions）
      var dmMessage = TRPGMessageEntity(
        gameId: game.id!,
        role: 'dm',
        content: fullContent,
        suggestions: suggestions,
        createdAt: DateTime.now(),
      );
      await _messageRepository.createMessage(dmMessage);
      messages.add(dmMessage);

      // 更新当前显示的建议列表
      currentSuggestions.value = suggestions;

      // 所有操作完成后才结束 streaming 状态
      isStreaming.value = false;
      streamingMessage.value = null;
    } catch (e) {
      error.value = '发送消息失败：$e';
      isStreaming.value = false;
      streamingMessage.value = null;
    }
  }

  /// 构建对话历史
  Future<List<ChatCompletionMessage>> _buildChatMessages() async {
    var result = <ChatCompletionMessage>[];

    // 系统提示词
    var systemPrompt = PresetPrompt.dungeonPrompt;
    result.add(ChatCompletionMessage.system(content: systemPrompt));

    // 历史消息
    for (var msg in messages.value) {
      if (msg.role == 'player') {
        result.add(
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(msg.content),
          ),
        );
      } else {
        result.add(ChatCompletionMessage.assistant(content: msg.content));
      }
    }

    return result;
  }

  /// 生成行动建议（私有方法）
  Future<List<String>> _generateActionSuggestions({
    required String dmMessage,
    required ModelEntity model,
    required ProviderEntity provider,
  }) async {
    try {
      isGeneratingSuggestions.value = true;

      var suggestions = await _service.getSuggestions(
        dmMessage: dmMessage,
        provider: provider,
        model: model,
      );

      return suggestions;
    } catch (e) {
      // 静默失败
      return [];
    } finally {
      isGeneratingSuggestions.value = false;
    }
  }

  /// 获取默认模型
  Future<ModelEntity?> _getDefaultModel() async {
    var models = await _modelRepository.getAllModels();
    return models.isNotEmpty ? models.first : null;
  }
}
