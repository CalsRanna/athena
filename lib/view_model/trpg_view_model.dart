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
import 'package:athena/service/model_resolver.dart';
import 'package:athena/service/trpg_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

class TRPGViewModel {
  // Repositories
  late final TRPGGameRepository _gameRepository;
  late final TRPGMessageRepository _messageRepository;
  late final ModelRepository _modelRepository;
  late final ProviderRepository _providerRepository;

  // Services
  late final TRPGService _service;
  late final SettingViewModel _settingViewModel;
  late final ModelResolver _modelResolver;

  TRPGViewModel({
    required TRPGGameRepository gameRepository,
    required TRPGMessageRepository messageRepository,
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required TRPGService service,
    required SettingViewModel settingViewModel,
    required ModelResolver modelResolver,
  })  : _gameRepository = gameRepository,
        _messageRepository = messageRepository,
        _modelRepository = modelRepository,
        _providerRepository = providerRepository,
        _service = service,
        _settingViewModel = settingViewModel,
        _modelResolver = modelResolver;

  // Signals
  final currentGame = signal<TRPGGameEntity?>(null);
  final messages = listSignal<TRPGMessageEntity>([]);
  final savedGames = listSignal<TRPGGameWithPreview>([]);
  final isStreaming = signal(false);
  final isGeneratingSuggestions = signal(false);
  final currentSuggestions = listSignal<String>([]);
  final showInputPanel = signal(false);
  final error = signal<String?>(null);

  final streamingMessage = signal<TRPGMessageEntity?>(null);

  /// 创建新游戏
  Future<TRPGGameEntity?> createNewGame() async {
    try {
      var model = await _modelResolver.resolveModel(
        preferredModelId: _settingViewModel.shortModelId.value,
      );
      if (model == null) {
        error.value = '未找到可用的模型';
        return null;
      }

      var now = DateTime.now();
      var game = TRPGGameEntity(
        modelId: model.id!,
        createdAt: now,
        updatedAt: now,
      );

      var gameId = await _gameRepository.createGame(game);
      game = game.copyWith(id: gameId);
      currentGame.value = game;

      messages.value = [];

      await sendPlayerAction('开始游戏');
      return game;
    } catch (e) {
      error.value = '创建游戏失败：$e';
      return null;
    }
  }

  /// 获取所有存档
  Future<void> getSavedGames() async {
    try {
      savedGames.value = await _gameRepository.getAllGamesWithPreview();
    } catch (e) {
      error.value = '获取存档失败：$e';
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
      var messageIndex = messages.value.indexOf(message);
      if (messageIndex < 0) return;

      var toRemove = messages.value.skip(messageIndex).toList();

      for (var msg in toRemove) {
        if (msg.id != null) {
          await _messageRepository.deleteMessage(msg.id!);
        }
      }

      messages.value = messages.value.take(messageIndex).toList();
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

      var loadedMessages = await _messageRepository.getMessagesByGameId(gameId);
      messages.value = loadedMessages;
    } catch (e) {
      error.value = '加载游戏失败：$e';
    }
  }

  /// 发送玩家行动
  Future<void> sendPlayerAction(String action) async {
    if (isStreaming.value) return;

    var game = currentGame.value;
    if (game == null) return;

    try {
      currentSuggestions.value = [];
      showInputPanel.value = false;

      var playerMessage = TRPGMessageEntity(
        gameId: game.id!,
        role: 'player',
        content: action,
        createdAt: DateTime.now(),
      );
      await _messageRepository.createMessage(playerMessage);
      messages.add(playerMessage);

      var chatMessages = await _buildChatMessages();

      var model = await _modelRepository.getModelById(game.modelId);
      if (model == null) return;

      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) return;

      streamingMessage.value = TRPGMessageEntity(
        gameId: game.id!,
        role: 'dm',
        content: '',
        createdAt: DateTime.now(),
      );

      isStreaming.value = true;

      var stream = _service.getDMResponse(
        messages: chatMessages,
        provider: provider,
        model: model,
      );

      var fullContent = '';
      await for (var chunk in stream) {
        var choice = chunk.choices?.firstOrNull;
        if (choice == null) continue;
        var delta = choice.delta.content ?? '';
        fullContent += delta;
        streamingMessage.value = streamingMessage.value!.copyWith(
          content: fullContent,
        );
      }

      var suggestions = await _generateActionSuggestions(
        dmMessage: fullContent,
        model: model,
        provider: provider,
      );

      var dmMessage = TRPGMessageEntity(
        gameId: game.id!,
        role: 'dm',
        content: fullContent,
        suggestions: suggestions,
        createdAt: DateTime.now(),
      );
      await _messageRepository.createMessage(dmMessage);
      messages.add(dmMessage);

      currentSuggestions.value = suggestions;

      isStreaming.value = false;
      streamingMessage.value = null;
    } catch (e) {
      error.value = '发送消息失败：$e';
      AthenaDialog.error(e.toString());
      isStreaming.value = false;
      streamingMessage.value = null;
    }
  }

  /// 构建对话历史
  Future<List<ChatMessage>> _buildChatMessages() async {
    var result = <ChatMessage>[];

    var systemPrompt = PresetPrompt.dungeonPrompt;
    result.add(ChatMessage.system(systemPrompt));

    for (var msg in messages.value) {
      if (msg.role == 'player') {
        result.add(ChatMessage.user(msg.content));
      } else {
        result.add(ChatMessage.assistant(content: msg.content));
      }
    }

    return result;
  }

  /// 生成行动建议
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
      return [];
    } finally {
      isGeneratingSuggestions.value = false;
    }
  }
}
