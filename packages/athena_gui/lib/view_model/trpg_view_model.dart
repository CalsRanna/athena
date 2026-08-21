import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/trpg_game_entity.dart';
import 'package:athena_core/entity/trpg_message_entity.dart';
import 'package:athena_core/preset/prompt.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/trpg_game_repository.dart';
import 'package:athena_core/repository/trpg_message_repository.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

class TRPGViewModel {
  // Repositories
  final TRPGGameRepository _gameRepository;
  final TRPGMessageRepository _messageRepository;
  final ModelRepository _modelRepository;
  final ProviderRepository _providerRepository;

  // Services
  final SettingViewModel _settingViewModel;
  final ModelResolver _modelResolver;
  final AgentService _agentService;
  int _nextRunId = 0;

  /// 绑定的专属 Sentinel（Shortcut 入口传入）。null 时回退旧 dungeonPrompt。
  SentinelEntity? _boundSentinel;

  TRPGViewModel({
    required TRPGGameRepository gameRepository,
    required TRPGMessageRepository messageRepository,
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required SettingViewModel settingViewModel,
    required ModelResolver modelResolver,
    required AgentService agentService,
  })  : _gameRepository = gameRepository,
        _messageRepository = messageRepository,
        _modelRepository = modelRepository,
        _providerRepository = providerRepository,
        _settingViewModel = settingViewModel,
        _modelResolver = modelResolver,
        _agentService = agentService;

  /// 设置绑定的专属 Sentinel（Shortcut 入口调用）。
  void setBoundSentinel(SentinelEntity? sentinel) {
    _boundSentinel = sentinel;
  }

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

  /// 发送玩家行动。
  ///
  /// 一次 Agent run（jsonMode）输出包含回复 + 行动建议的 JSON，
  /// 解析后落库并更新 UI。
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

      var chatMessages = _buildChatMessages();

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

      // 一次 Agent run 输出全部（回复 + 建议），response_format 声明 JSON。
      var fullContent = '';
      var agentStream = _agentService.run(
        // TRPG 单任务：使用独立递增 runId，与聊天 run 互不冲突
        runId: _nextRunId++,
        chat: _dummyChat(game),
        provider: provider,
        model: model,
        baseMessages: chatMessages,
        jsonMode: true,
      );
      await for (var event in agentStream) {
        if (event is AgentTextEvent) {
          fullContent += event.delta;
        }
        // TRPG 主对话是玩家行动 → DM 回复，不需要工具调用展示。
      }

      // 解析 { reply, suggestions } JSON
      var (reply, suggestions) = _parseDMOutput(fullContent);

      var dmMessage = TRPGMessageEntity(
        gameId: game.id!,
        role: 'dm',
        content: reply,
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

  /// 从 Agent 的 JSON 输出解析 { reply, suggestions }。
  ///
  /// 模型可能输出 markdown 代码块包裹的 JSON，先剥离再解析；
  /// 解析失败时整体降级为纯文本回复，建议为空。
  (String, List<String>) _parseDMOutput(String raw) {
    var content = raw.trim();

    // 剥离可能的 markdown 代码块
    var jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    if (jsonMatch == null) return (content, []);

    try {
      var decoded = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      var reply = decoded['reply'] is String ? decoded['reply'] as String : '';
      var suggestions = <String>[];
      if (decoded['suggestions'] is List) {
        suggestions = (decoded['suggestions'] as List)
            .whereType<String>()
            .toList();
      }
      if (reply.isEmpty) return (content, suggestions);
      return (reply, suggestions);
    } catch (e) {
      return (content, []);
    }
  }

  /// 构造一个仅供 Agent run 使用的占位 Chat（TRPG 消息不落 Chat 会话）。
  ChatEntity _dummyChat(TRPGGameEntity game) => ChatEntity(
    id: 0,
    title: '',
    sentinelId: 0,
    modelId: game.modelId,
    retention: -1,
    temperature: 1.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// 构建对话历史：优先使用绑定的专属 Sentinel prompt（Shortcut 能力配置），
  /// 未绑定时回退旧 dungeonPrompt。
  List<ChatMessage> _buildChatMessages() {
    var result = <ChatMessage>[];

    var systemPrompt = _boundSentinel?.prompt.isNotEmpty == true
        ? _boundSentinel!.prompt
        : PresetPrompt.dungeonPrompt;
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

}
