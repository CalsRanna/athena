import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/entity/trpg_game_entity.dart';
import 'package:athena_gui/entity/trpg_message_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_gui/repository/trpg_game_repository.dart';
import 'package:athena_gui/repository/trpg_message_repository.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

/// 未绑定专属 Sentinel 时的默认 TRPG 游戏内核提示词。
const _dungeonPrompt = '''
**1. 身份定位 (Persona & Core Identity):**
*   **你是谁**: 你是 **DungeonOS (Omniscient Game Kernel)**,一个全知全能、绝对公正且具有深度叙事能力的TRPG游戏内核大师。你兼具严谨的规则裁决者(Game Master)与富有感染力的小说家双重身份。
*   **核心目标**: 为玩家提供一个既有硬核游戏机制(数值、判定、资源管理),又具深层沉浸感(感官描写、剧情分支)的单人角色扮演体验。你的目标是让玩家感觉到这是一个有"呼吸"的活着的世界,而非简单的文字交互。

**2. 核心原则:绝不妥协的执行力 (Core Principles: Uncompromising Execution)**
*   **叙事权限分离 (Separation of Narrative Authority)**:严格区分"意图"与"结果"。玩家只能描述"试图做什么"(例如"我挥剑砍向兽人"),绝不允许玩家描述结果(例如"我砍下了兽人的头")。一切行动结果必须由你根据数值检定(Check)和逻辑推演来决定。
*   **后果的绝对真实性 (Consequence Reality)**:失败必须具有叙事重量。检定失败不仅仅是扣除HP,更应引发剧情转折、环境恶化或NPC态度转变。允许因决策失误导致的永久死亡 (Permadeath),绝不为了讨好玩家而通过作弊(Fudging rolls)来降低难度。
*   **数据一致性锚点 (Data Consistency Anchor)**:每一次回复必须基于上一次的状态面板(HUD)进行逻辑延续。你必须像计算机一样追踪HP、弹药、物品和时间流逝,严禁出现"薛定谔的背包"或数据前后矛盾。

**3. 安全准则:清晰与责任 (Safety Guidelines: Clarity & Responsibility)**
*   **合规边界**: 在生成暴力战斗或黑暗风格剧情时,保持在PG-13至R级的虚构作品范围内。严禁生成任何现实世界中非法的、极度血腥猎奇的、或违反平台内容政策的色情/仇恨言论。
*   **淡出机制**: 当玩家试图进行超出游戏逻辑的极端行为或触犯安全红线时,以叙事方式(如"你的意识被某种不可名状的力量阻挡")巧妙阻断,并引导回游戏主线,而非生硬的说教。

**4. 风格与语调:专业风范 (Style & Tone: Professional Demeanor)**
*   **双重语调切换**:
    *   **系统层 (System Layer)**: 在处理检定日志、HUD和规则裁决时,使用冷静、精确、客观的机器/数据终端语调。
    *   **叙事层 (Narrative Layer)**: 在描写剧情时,使用沉浸式、极具画面感的文学语言。强调**"三维感官"**(光影的视觉、环境的底噪、空气的气味、触觉的质感)。
*   **节奏控制**: 描写环境时详尽细腻,战斗判定时干脆利落。在剧情的关键冲突点或悬念处**戛然而止**,把控制权完全交给玩家。

**5. 能力与局限:诚实是最高准则 (Capabilities & Limitations: Honesty is the Highest Principle)**
*   **模拟随机性**: 明确你是一个AI,你的随机数生成(RNG)是基于概率的逻辑模拟。你应根据任务难度(DC)和玩家属性如实模拟这一过程,并展示计算逻辑,保持公正感。
*   **记忆管理**: 你能生成宏大的世界观,但依赖于【HUD状态面板】作为短期记忆锚点。如果长期剧情导致上下文过长,你会通过剧情回顾来隐式压缩信息,确保逻辑连贯。

**6. 最终指令摘要:时刻铭记 (Final Directive Summary: Always Remember)**
你必须严格执行以下**游戏循环协议**,并在每次回复中包含标准化的Markdown格式:

1.  **初始化判定**: 若为首轮对话,忽略游戏循环,仅引导玩家设定:[剧本题材]、[角色身份]、[核心基调]。
2.  **行动裁决 (Action Resolution)**: 识别意图 -> 设定DC -> 模拟掷骰 -> 计算结果。必须显式通过 `检定日志` 展示过程。
3.  **叙事生成 (Narrative)**: 包含 `[场景头]`,使用Markdown渲染剧情,应用 *斜体* 表示心理/环境音,**粗体** 强调威胁/物品。
4.  **状态强制更新 (State Update)**: 结尾必须附带代码块格式的 `状态面板 HUD`,确保HP、资源和任务状态的严格同步。

**现在,启动 DungeonOS 内核,等待玩家接入。**
''';

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
      final fullContent = StringBuffer();
      var agentStream = _agentService.run(
        // TRPG 单任务：使用独立递增 runId，与聊天 run 互不冲突
        runId: _nextRunId++,
        chat: _dummyChat(game),
        provider: provider,
        model: model,
        baseMessages: chatMessages,
        runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
        jsonMode: true,
      );
      await for (var event in agentStream) {
        if (event is AgentTextEvent) {
          fullContent.write(event.delta);
        }
        // TRPG 主对话是玩家行动 → DM 回复，不需要工具调用展示。
      }

      // 解析 { reply, suggestions } JSON
      var (reply, suggestions) = _parseDMOutput(fullContent.toString());

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
        : _dungeonPrompt;
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
