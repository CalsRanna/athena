import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';

import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/user_settings_store.dart';
import 'package:athena_core/util/retry.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals.dart';

/// 应用设置的 ViewModel。
///
/// 持久化走 core 的 [UserSettingsStore]（`~/.athena/setting.yaml`，与 TUI 共用
/// 同一份文件）。这里只定义 GUI 自己的键名——键名的语义属于这一端，core 只负责
/// 存；core 自己也消费的键（如 Brave API key）走 store 的具名访问器，不在这里
/// 另写一份字面量。
class SettingViewModel {
  // GUI 偏好的键名
  static const String _keyChatModelId = 'chat_model_id';
  static const String _keyChatNamingModelId = 'chat_naming_model_id';
  static const String _keySentinelMetadataGenerationModelId =
      'sentinel_metadata_generation_model_id';
  static const String _keyMaxRetries = 'max_retries';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyTextSize = 'text_size';

  // 模型 ID 设置
  final chatModelId = signal('');
  final chatNamingModelId = signal('');
  final sentinelMetadataGenerationModelId = signal('');
  final chatModel = signal<ModelEntity?>(null);
  final chatNamingModel = signal<ModelEntity?>(null);

  final sentinelMetadataGenerationModel = signal<ModelEntity?>(null);
  final chatModelProvider = signal<ProviderEntity?>(null);
  final chatNamingModelProvider = signal<ProviderEntity?>(null);
  final sentinelMetadataGenerationModelProvider = signal<ProviderEntity?>(null);

  /// 新建会话的审批档位起点（会话自己的档位在 `ChatEntity.approvalMode`）。
  ///
  /// 没有设置项：它只在启动时由 [AgentSettings.init] 从旧的全局设置播种
  /// 一次，供 `ChatViewModel` 给草稿定初值。
  Signal<ApprovalMode> get newChatApprovalMode =>
      _agentSettings.newChatApprovalMode;

  /// 后台任务完成后是否自动起一个汇报回合。
  Signal<bool> get backgroundTaskReports =>
      _agentSettings.backgroundTaskReports;

  /// 未单独配置输出上限的模型共用的默认输出上限（设置 → Agent）。
  Signal<int> get defaultOutputLimit => _agentSettings.defaultOutputLimit;

  final maxRetries = signal(10);
  final braveApiKey = signal('');
  // 主题模式：默认浅色，可在设置中切换深色/浅色/跟随系统
  final themeMode = signal<ThemeMode>(ThemeMode.light);

  /// 会话消息字号档位（设置 → General → Appearance → Text size）。
  final textSize = signal<AthenaTextSize>(AthenaTextSize.medium);

  final ModelRepository _modelRepository;
  final ProviderRepository _providerRepository;
  final LlmClient _llmClient;
  final AgentSettings _agentSettings;
  final FileStorage _storage;

  SettingViewModel({
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required LlmClient llmClient,
    required AgentSettings agentSettings,
    required FileStorage storage,
  }) : _modelRepository = modelRepository,
       _providerRepository = providerRepository,
       _llmClient = llmClient,
       _agentSettings = agentSettings,
       _storage = storage;

  /// `~/.athena/setting.yaml`（与 TUI 共用同一个文件）。
  UserSettingsStore get _settings => _storage.userSettings;

  /// 清除所有设置（恢复默认）
  Future<void> clearAllSettings() async {
    await _settings.clear();
    await initSignals(); // 重新加载默认值
  }

  /// 加载所有设置
  Future<void> initSignals() async {
    for (final key in [
      _keyChatModelId,
      _keyChatNamingModelId,
      _keySentinelMetadataGenerationModelId,
    ]) {
      // 更早的版本把模型 id 存成整数;启动升级时保留了 整数 → UUID 的映射,
      // 这里换成 UUID 并落盘。get() 保留原始类型,这个 is int 判断才成立。
      final old = await _settings.get(key);
      if (old is int) {
        await _settings.setString(key, _storage.legacyModelIds['$old'] ?? '');
      }
    }
    chatModelId.value = await _settings.getString(_keyChatModelId) ?? '';
    chatNamingModelId.value =
        await _settings.getString(_keyChatNamingModelId) ?? '';
    sentinelMetadataGenerationModelId.value =
        await _settings.getString(_keySentinelMetadataGenerationModelId) ?? '';
    await _agentSettings.init();
    maxRetries.value = await _settings.getInt(_keyMaxRetries) ?? 10;
    _llmClient.updateRetryConfig(RetryConfig(maxAttempts: maxRetries.value));
    braveApiKey.value = await _settings.loadBraveApiKey() ?? '';
    chatModel.value = await _modelRepository.getModelById(chatModelId.value);
    chatNamingModel.value = await _modelRepository.getModelById(
      chatNamingModelId.value,
    );
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      sentinelMetadataGenerationModelId.value,
    );
    if (chatModel.value != null) {
      chatModelProvider.value = await _providerRepository.getProviderById(
        chatModel.value!.providerId,
      );
    }
    if (chatNamingModel.value != null) {
      chatNamingModelProvider.value = await _providerRepository.getProviderById(
        chatNamingModel.value!.providerId,
      );
    }
    if (sentinelMetadataGenerationModel.value != null) {
      sentinelMetadataGenerationModelProvider.value = await _providerRepository
          .getProviderById(sentinelMetadataGenerationModel.value!.providerId);
    }
    await initThemeMode();
    await initTextSize();
  }

  /// 从设置文件加载主题模式（启动时调用）。
  Future<void> initThemeMode() async {
    final saved = await _settings.getString(_keyThemeMode);
    themeMode.value = ThemeMode.values.asNameMap()[saved] ?? ThemeMode.light;
  }

  /// 切换主题模式并持久化。
  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setString(_keyThemeMode, mode.name);
    themeMode.value = mode;
  }

  /// 从设置文件加载字号档位（启动时调用）。
  Future<void> initTextSize() async {
    final saved = await _settings.getString(_keyTextSize);
    textSize.value =
        AthenaTextSize.values.asNameMap()[saved] ?? AthenaTextSize.medium;
  }

  /// 切换固定字号档位并持久化，由 `AthenaWorkspaceTextSize` 在消息列表内应用。
  Future<void> setTextSize(AthenaTextSize size) async {
    await _settings.setString(_keyTextSize, size.name);
    textSize.value = size;
  }

  /// 更新聊天模型 ID
  Future<void> updateChatModelId(String modelId) async {
    await _settings.setString(_keyChatModelId, modelId);
    chatModelId.value = modelId;
    chatModel.value = await _modelRepository.getModelById(modelId);
    if (chatModel.value != null) {
      chatModelProvider.value = await _providerRepository.getProviderById(
        chatModel.value!.providerId,
      );
    }
  }

  /// 更新聊天命名模型 ID
  Future<void> updateChatNamingModelId(String modelId) async {
    await _settings.setString(_keyChatNamingModelId, modelId);
    chatNamingModelId.value = modelId;
    chatNamingModel.value = await _modelRepository.getModelById(modelId);
    if (chatNamingModel.value != null) {
      chatNamingModelProvider.value = await _providerRepository.getProviderById(
        chatNamingModel.value!.providerId,
      );
    }
  }

  /// 更新 Sentinel 元数据生成模型 ID
  Future<void> updateSentinelMetadataGenerationModelId(String modelId) async {
    await _settings.setString(_keySentinelMetadataGenerationModelId, modelId);
    sentinelMetadataGenerationModelId.value = modelId;
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      modelId,
    );
    if (sentinelMetadataGenerationModel.value != null) {
      sentinelMetadataGenerationModelProvider.value = await _providerRepository
          .getProviderById(sentinelMetadataGenerationModel.value!.providerId);
    }
  }

  /// 更新最大重试次数
  Future<void> updateMaxRetries(int max) async {
    await _settings.setInt(_keyMaxRetries, max);
    maxRetries.value = max;
    _llmClient.updateRetryConfig(RetryConfig(maxAttempts: max));
  }

  /// 更新 Brave Search API Key。
  ///
  /// 写入的是 `UserSettingsStore.braveApiKeyKey`——core 的 `WebSearchTool`
  /// 读的就是这个键，两处不再各写一份字面量。
  Future<void> updateBraveApiKey(String key) async {
    await _settings.saveBraveApiKey(key);
    braveApiKey.value = key;
  }

  /// 开关后台任务完成后的自动汇报。
  Future<void> updateBackgroundTaskReports(bool enabled) async {
    await _agentSettings.updateBackgroundTaskReports(enabled);
  }

  /// 更新未单独配置的模型共用的默认输出上限。
  Future<void> updateDefaultOutputLimit(int limit) async {
    await _agentSettings.updateDefaultOutputLimit(limit);
  }

  /// 重置:清空全部业务数据文件并重新种子内置角色,再清空设置。
  Future<bool> resetData() async {
    await _storage.reset();
    await const SentinelSeed().applyIfNeeded(
      sentinelRepo: _storage.sentinelRepository,
    );
    await clearAllSettings();
    return true;
  }
}
