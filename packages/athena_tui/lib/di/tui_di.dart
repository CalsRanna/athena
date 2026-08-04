import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/file_update_tool.dart';
import 'package:athena_core/agent/tool/file_write_tool.dart';
import 'package:athena_core/agent/tool/powershell_shell_tool.dart';
import 'package:athena_core/agent/tool/sentinel_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:athena_core/agent/tool/web_search_tool.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
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
import 'package:athena_core/util/platform_util.dart';
import 'package:athena_tui/bridge/tui_agent_bridge.dart';
import 'package:athena_tui/seed/preset_seed.dart';
import 'package:athena_tui/storage/json_file_key_value_store.dart';
import 'package:athena_tui/storage/jsonl_chat_repository.dart';
import 'package:athena_tui/storage/jsonl_message_repository.dart';
import 'package:athena_tui/storage/jsonl_model_repository.dart';
import 'package:athena_tui/storage/jsonl_provider_repository.dart';
import 'package:athena_tui/storage/jsonl_sentinel_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';
import 'package:athena_tui/view_model/chat_controller.dart';

/// TUI 组合根:手写依赖装配(镜像 athena_gui 的 di.dart,不用 GetIt)。
///
/// 数据目录默认 `~/.athena/tui/`,可通过 [dataDirectory] 覆盖(测试用)。
class TuiDi {
  TuiDi({String? dataDirectory}) {
    _dataDir = Directory(
      dataDirectory ??
          '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/'}/.athena/tui',
    );
    _build();
  }

  late final Directory _dataDir;

  // Repositories
  late final ChatRepository chatRepo;
  late final MessageRepository messageRepo;
  late final ModelRepository modelRepo;
  late final ProviderRepository providerRepo;
  late final SentinelRepository sentinelRepo;
  late final ExperienceRepository experienceRepo;

  // Storage
  late final KeyValueStore keyValueStore;

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
  /// 上下文窗口、价格、reasoning/vision)来自 models.dev 权威数据源,
  /// 种子数据仅作离线兜底。TTL(7 天)内缓存新鲜则秒返回。
  /// [syncModels] 在测试中置 false,避免发起网络请求。
  Future<void> initialize({bool syncModels = true}) async {
    await permissionService.load();
    await agentSettings.init();
    await const PresetSeed().applyIfNeeded(
      providerRepo: providerRepo,
      modelRepo: modelRepo,
      sentinelRepo: sentinelRepo,
    );
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

  void _build() {
    final messagesDir = Directory('${_dataDir.path}/messages');

    // ── Repositories(JSONL 实现) ──
    final idAllocator = IdAllocator(File('${_dataDir.path}/meta.json'));
    chatRepo = JsonlChatRepository(
      file: File('${_dataDir.path}/chats.jsonl'),
      messagesDir: messagesDir,
      idAllocator: idAllocator,
    );
    messageRepo = JsonlMessageRepository(
      messagesDir: messagesDir,
      idAllocator: idAllocator,
    );
    modelRepo = JsonlModelRepository(
      file: File('${_dataDir.path}/models.jsonl'),
      idAllocator: idAllocator,
    );
    providerRepo = JsonlProviderRepository(
      file: File('${_dataDir.path}/providers.jsonl'),
      idAllocator: idAllocator,
    );
    sentinelRepo = JsonlSentinelRepository(
      file: File('${_dataDir.path}/sentinels.jsonl'),
      idAllocator: idAllocator,
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
    skillRegistry.registerBuiltin(
      const Skill(
        name: 'self-evolve',
        description:
            'Guidance on self-evolution: creating skills, recording '
            'experiences, and optimizing sentinels to improve over time',
        body: EvolutionPrompt.fullBody,
        sourcePath: '(builtin)',
      ),
    );

    // ── 工具(桌面运行时 11 个,与 GUI 一致) ──
    final isWindows = PlatformUtil.isWindows;
    toolRegistry = ToolRegistry()
      ..registerAll([
        FileReadTool(),
        FileWriteTool(),
        FileUpdateTool(),
        isWindows ? PowerShellShellTool() : BashShellTool(),
        WebFetchTool(),
        WebSearchTool(store: keyValueStore),
        SkillTool(skillRegistry),
        SkillEvolveTool(skillRegistry: skillRegistry),
        ExperienceLearnTool(repository: experienceRepo),
        ExperienceRecallTool(repository: experienceRepo),
        SentinelEvolveTool(repository: sentinelRepo),
      ]);

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

    agentService = AgentService(
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
    );
  }
}
