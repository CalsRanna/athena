import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/chat_store.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_tui/bridge/tui_agent_bridge.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:path/path.dart' as p;
import 'package:athena_tui/view_model/chat_controller.dart';

/// TUI 组合根:手写依赖装配(镜像 athena_gui 的 di.dart,不用 GetIt)。
///
/// 数据目录默认 `~/.athena/`(与 GUI 共享,布局见 [FileStorage]),
/// 可通过 [dataDirectory] 覆盖(测试用)。
class TuiDi {
  TuiDi({
    String? dataDirectory,
    String? workspace,
    String? homeDir,
    this.agentServiceOverride,
  }) {
    _homeDir =
        homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    _dataDir = Directory(dataDirectory ?? '$_homeDir/.athena');
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
  late final FileStorage storage;
  late final UserSettingsStore userSettings;
  late final File userSettingsFile;

  // Agent 基础
  late final AgentSettings agentSettings;
  late final PermissionService permissionService;
  late final SkillRegistry skillRegistry;
  late final ToolRegistry toolRegistry;
  late final AgentService agentService;

  // Services
  late final ChatCompletionsService chatService;
  late final ChatStore chatStore;
  late final ChatMessageConverter messageService;
  late final ChatUpdateService supportService;
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
    await storage.load();
    await permissionService.load();
    await agentSettings.init();
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

  /// 启动时加载用户配置:读取持久化的默认模型 modelId,供 ChatController
  /// 启动时选中(provider 由 YamlProviderRepository 直接读 yaml)。
  Future<void> _importUserSettings() async {
    try {
      currentModelId = await userSettings.loadModelId();
      // ChatController 在 _build(构造)时创建,此时 yaml 尚未读;
      // 导入完成后注入默认模型
      chatController.setDefaultModelId(currentModelId);
    } catch (e) {
      LoggerUtil.w('Import user settings failed: $e');
    }
  }

  /// 持久化默认模型(modelId 字符串)到 yaml(/model 切换后调用)。
  Future<void> persistCurrentModelId(String modelId) async {
    await userSettings.saveModelId(modelId);
  }

  void _build() {
    final outputStore = ToolOutputStore(
      directory: Directory('${_dataDir.path}/tool_outputs'),
    );

    // ── Repositories(布局与装配见 FileStorage,与 GUI 共用)──
    // 用户配置与 provider 目录都跟随数据根:此前 setting.yaml 固定拼在
    // $HOME 下,`dataDirectory` 只覆盖 dataDirectory 而不同时覆盖 homeDir 时
    // (如某些测试),会把 provider 写进真实主目录去。
    userSettingsFile = File(p.join(_dataDir.path, 'setting.yaml'));
    storage = FileStorage(root: _dataDir, settingFile: userSettingsFile);
    chatRepo = storage.sessionRepository;
    messageRepo = storage.sessionRepository;
    modelRepo = storage.modelRepository;
    userSettings = storage.userSettings;
    providerRepo = storage.providerRepository;
    sentinelRepo = storage.sentinelRepository;
    experienceRepo = ExperienceRepository(homeDir: _homeDir);

    // ── Agent 基础 ──
    agentSettings = AgentSettings(store: userSettings);
    permissionService = PermissionService(
      store: PermissionStore(
        file: storage.permissionsFile,
        locks: storage.locks,
      ),
    );
    skillRegistry = SkillRegistry();
    skillRegistry.loadAll(homeDir: _homeDir);
    skillRegistry.registerBuiltin(kSelfEvolveSkill);

    // ── 工具 ──
    // 清单在 athena_core 的 buildToolRegistry;TUI 只额外指定工作目录。
    toolRegistry = buildToolRegistry(
      skillRegistry: skillRegistry,
      experienceRepository: experienceRepo,
      sentinelRepository: sentinelRepo,
      settings: userSettings,
      outputStore: outputStore,
      backgroundTasks: BackgroundTaskService(
        stateDirectory: storage.backgroundTasksDir,
        locks: storage.locks,
      ),
      defaultWorkdir: _workspace,
    );

    // ── Services ──
    final llmClient = LlmClient();
    chatService = ChatCompletionsService(
      llmClient: llmClient,
      agentSettings: agentSettings,
    );
    chatStore = ChatStore(
      chatRepository: chatRepo,
      messageRepository: messageRepo,
      modelRepository: modelRepo,
      providerRepository: providerRepo,
      sentinelRepository: sentinelRepo,
    );
    messageService = ChatMessageConverter(
      messageRepository: messageRepo,
      outputStore: outputStore,
    );
    supportService = ChatUpdateService(
      chatRepository: chatRepo,
      providerRepository: providerRepo,
      chatService: chatService,
    );
    // 缓存放数据目录(与 GUI 共享):独立于 systemTemp,避免重启清空
    // 临时目录后每次都重新拉取 3.2MB
    modelCatalogService = ModelCatalogService(
      modelRepository: modelRepo,
      providerRepository: providerRepo,
      chatRepository: chatRepo,
      cacheFilePath: storage.catalogCacheFile.path,
    );
    modelResolver = ModelResolver(
      modelRepo: modelRepo,
      providerRepo: providerRepo,
    );

    agentService =
        agentServiceOverride ??
        AgentService(
          chatService: chatService,
          toolRegistry: toolRegistry,
          skillRegistry: skillRegistry,
        );

    // ── Bridge + Controller ──
    agentBridge = TuiAgentBridge(
      agentService: agentService,
      chatStore: chatStore,
      messageService: messageService,
      chatService: chatService,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      sentinelRepo: sentinelRepo,
      chatRepo: chatRepo,
      supportService: supportService,
      agentSettings: agentSettings,
      permissionService: permissionService,
      experienceRepository: experienceRepo,
    );
    chatController = ChatController(
      chatStore: chatStore,
      bridge: agentBridge,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      providerRepo: providerRepo,
      sentinelRepo: sentinelRepo,
      supportService: supportService,
      // 模型切换写回 setting.yaml(provider 由 YamlProviderRepository
      // 直接持久化到 providers/ 下的单文件)
      onModelSwitched: persistCurrentModelId,
    );
  }
}
