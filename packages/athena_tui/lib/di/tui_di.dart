import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_tui/bridge/tui_agent_bridge.dart';
import 'package:athena_tui/seed/sentinel_seed.dart';
import 'package:athena_tui/storage/id_allocator.dart';
import 'package:athena_tui/storage/json_array_model_repository.dart';
import 'package:athena_tui/storage/json_array_sentinel_repository.dart';
import 'package:athena_tui/storage/json_file_key_value_store.dart';
import 'package:athena_tui/storage/jsonl_session_repository.dart';
import 'package:athena_tui/storage/user_settings_store.dart';
import 'package:athena_tui/storage/yaml_provider_repository.dart';
import 'package:athena_tui/view_model/chat_controller.dart';

/// TUI 组合根:手写依赖装配(镜像 athena_gui 的 di.dart,不用 GetIt)。
///
/// 数据目录默认 `~/.athena/tui/`,可通过 [dataDirectory] 覆盖(测试用)。
class TuiDi {
  TuiDi({
    String? dataDirectory,
    String? workspace,
    String? homeDir,
    this.agentServiceOverride,
  }) {
    _homeDir = homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    _dataDir = Directory(
      dataDirectory ?? '$_homeDir/.athena/tui',
    );
    _workspace = workspace ?? Directory.current.path;
    _build();
  }

  /// 测试注入的假 Agent 服务(ui_test 用,避免发送测试触发真实网络)。
  /// 为 null 时 _build 构造真实 [AgentService]。
  final AgentService? agentServiceOverride;

  late final String _homeDir;

  late final Directory _dataDir;
  late final String _workspace;

  /// 启动时从 setting.yaml 导入的持久化模型 modelId(null = 未配置)。
  String? currentModelId;

  /// 当前工作区目录(Agent 工具的工作根目录)。
  String get workspace => _workspace;

  // Repositories
  late final ChatRepository chatRepo;
  late final MessageRepository messageRepo;
  late final ModelRepository modelRepo;
  late final ProviderRepository providerRepo;
  late final SentinelRepository sentinelRepo;
  late final ExperienceRepository experienceRepo;

  // Storage
  late final KeyValueStore keyValueStore;
  late final UserSettingsStore userSettings;
  late final File userSettingsFile;
  late final IdAllocator _idAllocator;

  // Agent 基础
  late final AgentSettings agentSettings;
  late final PermissionService permissionService;
  late final SkillRegistry skillRegistry;
  late final ToolRegistry toolRegistry;
  late final AgentService agentService;

  // Services
  late final ChatService chatService;
  late final ChatManageService manageService;
  late final ChatMessageService messageService;
  late final ChatSupportService supportService;
  late final ModelCatalogService modelCatalogService;
  late final ModelResolver modelResolver;

  // Bridge + Controller
  late final TuiAgentBridge agentBridge;
  late final ChatController chatController;

  Directory get dataDir => _dataDir;

  /// 启动初始化:加载持久化状态、首次种子、同步 models.dev 模型目录。
  /// 在 runApp 前 await。
  ///
  /// [syncModels] 置 true(默认)时**阻塞等待**同步:模型元数据(名称、
  /// 上下文窗口、价格、reasoning/vision)来自 models.dev 权威数据源。
  /// TTL(7 天)内缓存新鲜则秒返回。
  /// [syncModels] 在测试中置 false,避免发起网络请求。
  Future<void> initialize({bool syncModels = true}) async {
    await permissionService.load();
    await agentSettings.init();
    // 先迁移旧存储布局(chats.jsonl + messages/ → sessions/、
    // models/sentinels 的 jsonl → json),再种子:迁移必须发生在任何
    // id 分配与种子写入之前,保证旧 id 与计数不冲突
    await _migrateLegacyStorage();
    // 再迁移旧 providers.jsonl(若有),再种子:避免种子写入 yaml 后
    // 迁移被"yaml 非空"跳过
    await _importUserSettings();
    // 预设 provider/模型由 ModelCatalogService 从 models.dev 同步,
    // 这里只种子 Athena 角色(无外部数据源)
    await const SentinelSeed().applyIfNeeded(sentinelRepo: sentinelRepo);
    if (syncModels) {
      // 最多等 30s;同步失败(无网/超时)内部降级缓存,模型为空时
      // ChatController 会提示用户重试,不阻塞启动崩溃
      try {
        await modelCatalogService.syncIfNeeded().timeout(
              const Duration(seconds: 30),
            );
      } catch (e) {
        LoggerUtil.w('Model catalog sync timeout: $e');
      }
    }
  }

  /// 一次性迁移旧存储布局 → 新布局,完成后删除旧文件:
  /// - `chats.jsonl` + `messages/{chatId}.jsonl` → `sessions/{chatId}.jsonl`
  ///   (首行会话元数据 + 消息行,id 原样保留,不重新分配)
  /// - `models.jsonl` → `models.json`,`sentinels.jsonl` → `sentinels.json`
  /// - meta.json 计数 key 同步改路径(chat:会话目录,消息/模型/角色:新文件),
  ///   避免迁移后 id 从头分配与已有 id 冲突
  ///
  /// 必须在任何 id 分配与种子写入之前执行(initialize 开头调用)。
  Future<void> _migrateLegacyStorage() async {
    try {
      await _migrateLegacyChats();
      await _migrateLegacyList('models');
      await _migrateLegacyList('sentinels');
    } catch (e) {
      LoggerUtil.w('Migrate legacy storage failed: $e');
    }
  }

  Future<void> _migrateLegacyChats() async {
    final legacyChats = File('${_dataDir.path}/chats.jsonl');
    if (!await legacyChats.exists()) return;

    final legacyMessagesDir = Directory('${_dataDir.path}/messages');
    final sessionsDir = Directory('${_dataDir.path}/sessions');
    await sessionsDir.create(recursive: true);

    final meta = await _readMetaCounters();
    var migrated = 0;
    for (final line in await legacyChats.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final chatRow = Map<String, dynamic>.from(jsonDecode(line) as Map);
        final id = chatRow['id'];
        if (id is! int) continue;
        final sessionFile = File('${sessionsDir.path}/$id.jsonl');
        final buf = StringBuffer()
          ..writeln(jsonEncode({...chatRow, 'type': 'chat'}));
        // 消息行原样搬入(带 type 标注),id 不重新分配
        final legacyMsgFile = File('${legacyMessagesDir.path}/$id.jsonl');
        var msgCount = 0;
        if (await legacyMsgFile.exists()) {
          for (final mline in await legacyMsgFile.readAsLines()) {
            if (mline.trim().isEmpty) continue;
            try {
              final mrow =
                  Map<String, dynamic>.from(jsonDecode(mline) as Map);
              buf.writeln(jsonEncode({...mrow, 'type': 'message'}));
              msgCount++;
            } catch (_) {
              // 跳过损坏消息行
            }
          }
        }
        await sessionFile.writeAsString(buf.toString());
        // 消息计数:旧 key(messages/{id}.jsonl)迁到新 key(会话文件),
        // 取旧计数与迁移行数的较大者(旧计数含已删除消息)
        final oldMsgCount = meta.remove(legacyMsgFile.path) ?? 0;
        meta[sessionFile.path] =
            _maxCount(meta[sessionFile.path], oldMsgCount, msgCount);
        migrated++;
      } catch (_) {
        // 跳过损坏的 chat 行
      }
    }
    // chat 计数:旧 key(chats.jsonl)迁到会话目录 key
    final oldChatCount = meta.remove(legacyChats.path) ?? 0;
    meta[sessionsDir.path] =
        _maxCount(meta[sessionsDir.path], oldChatCount, migrated);
    await _writeMetaCounters(meta);
    // 内存计数缓存已过期(meta.json 被改写),清空让下次 next() 重读
    _idAllocator.reset();
    // 迁移完成删除旧文件,避免重复迁移
    try {
      await legacyChats.delete();
      if (await legacyMessagesDir.exists()) {
        await legacyMessagesDir.delete(recursive: true);
      }
    } catch (_) {}
    LoggerUtil.i('Migrated $migrated chats to sessions/');
  }

  /// 一次性迁移 jsonl 列表(models/sentinels)为 json 数组文件,id 原样保留。
  Future<void> _migrateLegacyList(String name) async {
    final legacy = File('${_dataDir.path}/$name.jsonl');
    if (!await legacy.exists()) return;

    final rows = <Map<String, dynamic>>[];
    for (final line in await legacy.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        rows.add(Map<String, dynamic>.from(jsonDecode(line) as Map));
      } catch (_) {
        // 跳过损坏行
      }
    }
    final target = File('${_dataDir.path}/$name.json');
    await target.writeAsString(jsonEncode(rows));
    // 计数 key 从旧 jsonl 路径迁到新 json 路径(取较大者,防 id 冲突)
    final meta = await _readMetaCounters();
    final oldCount = meta.remove(legacy.path) ?? 0;
    meta[target.path] = _maxCount(meta[target.path], oldCount, rows.length);
    await _writeMetaCounters(meta);
    _idAllocator.reset();
    try {
      await legacy.delete();
    } catch (_) {}
    LoggerUtil.i('Migrated $name.jsonl → $name.json (${rows.length} rows)');
  }

  Future<Map<String, int>> _readMetaCounters() async {
    final metaFile = File('${_dataDir.path}/meta.json');
    if (!await metaFile.exists()) return {};
    try {
      final json = jsonDecode(await metaFile.readAsString());
      if (json is! Map) return {};
      return {
        for (final entry in json.entries)
          if (entry.value is int) entry.key as String: entry.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMetaCounters(Map<String, int> counters) async {
    final metaFile = File('${_dataDir.path}/meta.json');
    await metaFile.parent.create(recursive: true);
    await metaFile.writeAsString(jsonEncode(counters));
  }

  static int _maxCount(int? a, int? b, int c) {
    var result = c;
    if (a != null && a > result) result = a;
    if (b != null && b > result) result = b;
    return result;
  }

  /// 启动时加载用户配置:
  /// - 读 yaml 用户配置的 provider(配过 key 的)到内存
  /// - 旧版 providers.jsonl(历史存储)合并:以旧文件的 id/baseUrl 为主,
  ///   用户 yaml 的 apiKey 覆盖;只把配了 key 的写回 yaml
  /// - 读取持久化的默认模型 modelId,供 ChatController 启动时选中
  Future<void> _importUserSettings() async {
    try {
      if (providerRepo is YamlProviderRepository) {
        await (providerRepo as YamlProviderRepository).load();
      }
      await _migrateLegacyProviders();
      currentModelId = await userSettings.loadModelId();
      // ChatController 在 _build(构造)时创建,此时 yaml 尚未读;
      // 导入完成后注入默认模型
      chatController.setDefaultModelId(currentModelId);
    } catch (e) {
      LoggerUtil.w('Import user settings failed: $e');
    }
  }

  /// 合并迁移:旧 providers.jsonl → 内存(仅首次,jsonl 存在时)。
  ///
  /// 以旧文件的 id/baseUrl 为主,内存(yaml 已 load 的用户配置)的
  /// apiKey 覆盖;经 [importProviders] 只把配了 key 的写回 yaml。
  /// 合并后删除旧 jsonl(避免每次启动重复迁移)。
  Future<void> _migrateLegacyProviders() async {
    final legacy = File('${_dataDir.path}/providers.jsonl');
    if (!await legacy.exists()) return;

    final legacyProviders = <ProviderEntity>[];
    for (final line in await legacy.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        legacyProviders.add(
          ProviderEntity.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {
        // 跳过损坏行
      }
    }
    if (legacyProviders.isEmpty) return;

    final memoryProviders = await providerRepo.getAllProviders();
    final memoryByName = {
      for (final p in memoryProviders) p.name: p,
    };
    final merged = <ProviderEntity>[];
    for (final legacyProvider in legacyProviders) {
      final memory = memoryByName[legacyProvider.name];
      merged.add(legacyProvider.copyWith(
        apiKey: memory?.apiKey.isNotEmpty == true
            ? memory!.apiKey
            : legacyProvider.apiKey,
      ));
    }
    // 内存中独有(旧文件没有,如用户新配的)也保留
    final legacyByName = {for (final p in legacyProviders) p.name: p};
    for (final memory in memoryProviders) {
      if (!legacyByName.containsKey(memory.name)) {
        merged.add(memory);
      }
    }
    await providerRepo.importProviders(merged);
    LoggerUtil.i(
      'Merged ${merged.length} providers from legacy providers.jsonl',
    );
    // 迁移完成删除旧文件,避免重复合并
    try {
      await legacy.delete();
    } catch (_) {}
  }

  /// 持久化默认模型(modelId 字符串)到 yaml(/model 切换后调用)。
  Future<void> persistCurrentModelId(String modelId) async {
    await userSettings.saveModelId(modelId);
  }

  void _build() {
    final sessionsDir = Directory('${_dataDir.path}/sessions');

    // ── Repositories ──
    _idAllocator = IdAllocator(File('${_dataDir.path}/meta.json'));
    // 会话存储:一个对话一个 sessions/{chatId}.jsonl(首行会话元数据 + 消息行),
    // 同一个实例同时承担 ChatRepository 与 MessageRepository 两个角色,
    // 对话与其消息同生命周期
    final sessionRepo = JsonlSessionRepository(
      sessionsDir: sessionsDir,
      idAllocator: _idAllocator,
    );
    chatRepo = sessionRepo;
    messageRepo = sessionRepo;
    modelRepo = JsonArrayModelRepository(
      file: File('${_dataDir.path}/models.json'),
      idAllocator: _idAllocator,
    );
    // yaml 用户配置(provider 权威存储)须在 providerRepo 之前初始化
    userSettingsFile = File('$_homeDir/.athena/setting.yaml');
    userSettings = UserSettingsStore(file: userSettingsFile);
    providerRepo = YamlProviderRepository(store: userSettings);
    sentinelRepo = JsonArraySentinelRepository(
      file: File('${_dataDir.path}/sentinels.json'),
      idAllocator: _idAllocator,
    );
    experienceRepo = ExperienceRepository();

    keyValueStore = JsonFileKeyValueStore(
      file: File('${_dataDir.path}/kv.json'),
    );

    // ── Agent 基础 ──
    agentSettings = AgentSettings(store: keyValueStore);
    permissionService = PermissionService(store: PermissionStore());
    skillRegistry = SkillRegistry(trustStore: SkillTrustStore());
    skillRegistry.loadAll();
    skillRegistry.registerBuiltin(kSelfEvolveSkill);

    // ── 工具 ──
    // 清单在 athena_core 的 buildToolRegistry;TUI 只额外指定工作目录。
    toolRegistry = buildToolRegistry(
      skillRegistry: skillRegistry,
      experienceRepository: experienceRepo,
      sentinelRepository: sentinelRepo,
      store: keyValueStore,
      defaultWorkdir: _workspace,
    );

    // ── Services ──
    final llmClient = LlmClient();
    chatService = ChatService(llmClient: llmClient);
    manageService = ChatManageService(
      chatRepository: chatRepo,
      messageRepository: messageRepo,
      modelRepository: modelRepo,
      providerRepository: providerRepo,
      sentinelRepository: sentinelRepo,
    );
    messageService = ChatMessageService(messageRepository: messageRepo);
    supportService = ChatSupportService(
      chatRepository: chatRepo,
      messageRepository: messageRepo,
      providerRepository: providerRepo,
      chatService: chatService,
    );
    // 缓存放 TUI 数据目录:独立于 systemTemp(GUI 共用文件但目录各自持久),
    // 避免重启清空临时目录后每次都重新拉取 3.2MB
    modelCatalogService = ModelCatalogService(
      modelRepository: modelRepo,
      providerRepository: providerRepo,
      chatRepository: chatRepo,
      cacheFilePath: '${_dataDir.path}/models_dev_cache.json',
    );
    modelResolver = ModelResolver(
      modelRepo: modelRepo,
      providerRepo: providerRepo,
    );

    agentService = agentServiceOverride ??
        AgentService(
          chatService: chatService,
          toolRegistry: toolRegistry,
          skillRegistry: skillRegistry,
        );

    // ── Bridge + Controller ──
    agentBridge = TuiAgentBridge(
      agentService: agentService,
      manageService: manageService,
      messageService: messageService,
      chatService: chatService,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      sentinelRepo: sentinelRepo,
      chatRepo: chatRepo,
      supportService: supportService,
      agentSettings: agentSettings,
      permissionService: permissionService,
      skillRegistry: skillRegistry,
    );
    chatController = ChatController(
      manageService: manageService,
      bridge: agentBridge,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      providerRepo: providerRepo,
      sentinelRepo: sentinelRepo,
      supportService: supportService,
      // 模型切换 / apiKey 变更写回 setting.yaml
      // 模型切换写回 yaml(provider 由 YamlProviderRepository 直接持久化)
      onModelSwitched: persistCurrentModelId,
    );
  }
}
