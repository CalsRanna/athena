import 'dart:convert';
import 'dart:io';

import 'package:athena/util/platform_util.dart';

import 'package:athena/database/database.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';

import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/util/retry.dart';
import 'package:athena/util/shared_preference_util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:window_manager/window_manager.dart';

/// SettingViewModel 使用 SharedPreferences 管理应用设置
/// 不依赖数据库，所有设置都存储在本地偏好设置中
class SettingViewModel {
  // SharedPreferences keys
  static const String _keyWindowHeight = 'window_height';
  static const String _keyWindowWidth = 'window_width';

  static const String _keyChatModelId = 'chat_model_id';
  static const String _keyChatNamingModelId = 'chat_naming_model_id';
  static const String _keySentinelMetadataGenerationModelId =
      'sentinel_metadata_generation_model_id';
  static const String _keyShortModelId = 'short_model_id';
  static const String _keyAuxiliaryModelId = 'auxiliary_model_id';
  static const String _keyMaxAgentIterations = 'max_agent_iterations';
  static const String _keyMaxRetries = 'max_retries';
  static const String _keyBraveApiKey = 'brave_api_key';
  // Window 尺寸
  final windowHeight = signal(720.0);
  final windowWidth = signal(960.0);
  // 模型 ID 设置
  final chatModelId = signal(0);
  final chatNamingModelId = signal(0);
  final sentinelMetadataGenerationModelId = signal(0);
  final shortModelId = signal(0);
  final auxiliaryModelId = signal(0);
  final chatModel = signal<ModelEntity?>(null);
  final chatNamingModel = signal<ModelEntity?>(null);

  final sentinelMetadataGenerationModel = signal<ModelEntity?>(null);
  final shortModel = signal<ModelEntity?>(null);
  final auxiliaryModel = signal<ModelEntity?>(null);
  final chatModelProvider = signal<ProviderEntity?>(null);
  final chatNamingModelProvider = signal<ProviderEntity?>(null);
  final sentinelMetadataGenerationModelProvider = signal<ProviderEntity?>(null);
  final shortModelProvider = signal<ProviderEntity?>(null);
  final auxiliaryModelProvider = signal<ProviderEntity?>(null);
  final maxAgentIterations = signal(100);
  final maxRetries = signal(10);
  final braveApiKey = signal('');

  late final ModelRepository _modelRepository;
  late final ProviderRepository _providerRepository;
  late final SentinelRepository _sentinelRepository;
  final ChatService _chatService;
  final ChatRepository _chatRepository;

  SettingViewModel({
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required SentinelRepository sentinelRepository,
    required ChatRepository chatRepository,
    required ChatService chatService,
  }) : _modelRepository = modelRepository,
       _providerRepository = providerRepository,
       _sentinelRepository = sentinelRepository,
       _chatRepository = chatRepository,
       _chatService = chatService;

  /// 清除所有设置（恢复默认）
  Future<void> clearAllSettings() async {
    final instance = await SharedPreferences.getInstance();
    await instance.clear();
    await initSignals(); // 重新加载默认值
  }

  /// 加载所有设置
  Future<void> initSignals() async {
    final instance = await SharedPreferences.getInstance();
    windowHeight.value = instance.getDouble(_keyWindowHeight) ?? 720.0;
    windowWidth.value = instance.getDouble(_keyWindowWidth) ?? 960.0;
    chatModelId.value = instance.getInt(_keyChatModelId) ?? 0;
    chatNamingModelId.value = instance.getInt(_keyChatNamingModelId) ?? 0;
    sentinelMetadataGenerationModelId.value =
        instance.getInt(_keySentinelMetadataGenerationModelId) ?? 0;
    shortModelId.value = instance.getInt(_keyShortModelId) ?? 0;
    auxiliaryModelId.value = instance.getInt(_keyAuxiliaryModelId) ?? 0;
    maxAgentIterations.value = instance.getInt(_keyMaxAgentIterations) ?? 100;
    maxRetries.value = instance.getInt(_keyMaxRetries) ?? 10;
    _chatService.updateRetryConfig(RetryConfig(maxAttempts: maxRetries.value));
    braveApiKey.value = instance.getString(_keyBraveApiKey) ?? '';
    chatModel.value = await _modelRepository.getModelById(chatModelId.value);
    chatNamingModel.value = await _modelRepository.getModelById(
      chatNamingModelId.value,
    );
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      sentinelMetadataGenerationModelId.value,
    );
    shortModel.value = await _modelRepository.getModelById(shortModelId.value);
    auxiliaryModel.value = await _modelRepository.getModelById(
      auxiliaryModelId.value,
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
    if (shortModel.value != null) {
      shortModelProvider.value = await _providerRepository.getProviderById(
        shortModel.value!.providerId,
      );
    }
    if (auxiliaryModel.value != null) {
      auxiliaryModelProvider.value = await _providerRepository.getProviderById(
        auxiliaryModel.value!.providerId,
      );
    }
  }

  /// 更新聊天模型 ID
  Future<void> updateChatModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyChatModelId, modelId);
    chatModelId.value = modelId;
    chatModel.value = await _modelRepository.getModelById(modelId);
    if (chatModel.value != null) {
      chatModelProvider.value = await _providerRepository.getProviderById(
        chatModel.value!.providerId,
      );
    }
  }

  /// 更新聊天命名模型 ID
  Future<void> updateChatNamingModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyChatNamingModelId, modelId);
    chatNamingModelId.value = modelId;
    chatNamingModel.value = await _modelRepository.getModelById(modelId);
    if (chatNamingModel.value != null) {
      chatNamingModelProvider.value = await _providerRepository.getProviderById(
        chatNamingModel.value!.providerId,
      );
    }
  }

  /// 更新 Sentinel 元数据生成模型 ID
  Future<void> updateSentinelMetadataGenerationModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keySentinelMetadataGenerationModelId, modelId);
    sentinelMetadataGenerationModelId.value = modelId;
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      modelId,
    );
    if (sentinelMetadataGenerationModel.value != null) {
      sentinelMetadataGenerationModelProvider.value = await _providerRepository
          .getProviderById(sentinelMetadataGenerationModel.value!.providerId);
    }
  }

  /// 更新短模型 ID
  Future<void> updateShortModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyShortModelId, modelId);
    shortModelId.value = modelId;
    shortModel.value = await _modelRepository.getModelById(modelId);
    if (shortModel.value != null) {
      shortModelProvider.value = await _providerRepository.getProviderById(
        shortModel.value!.providerId,
      );
    }
  }

  /// 更新辅助模型 ID
  Future<void> updateAuxiliaryModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyAuxiliaryModelId, modelId);
    auxiliaryModelId.value = modelId;
    auxiliaryModel.value = await _modelRepository.getModelById(modelId);
    if (auxiliaryModel.value != null) {
      auxiliaryModelProvider.value = await _providerRepository.getProviderById(
        auxiliaryModel.value!.providerId,
      );
    }
  }

  /// 更新最大重试次数
  Future<void> updateMaxRetries(int max) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyMaxRetries, max);
    maxRetries.value = max;
    _chatService.updateRetryConfig(RetryConfig(maxAttempts: max));
  }

  /// 更新 Brave Search API Key
  Future<void> updateBraveApiKey(String key) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setString(_keyBraveApiKey, key);
    braveApiKey.value = key;
  }

  /// 更新最大 Agent 迭代次数
  Future<void> updateMaxAgentIterations(int max) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyMaxAgentIterations, max);
    maxAgentIterations.value = max;
  }

  /// 更新窗口尺寸
  Future<void> updateWindowSize() async {
    final size = await windowManager.getSize();
    final instance = SharedPreferenceUtil.instance;
    await instance.setWindowHeight(size.height);
    await instance.setWindowWidth(size.width);

    windowHeight.value = size.height;
    windowWidth.value = size.width;
  }

  /// 导出数据到 JSON 文件
  Future<bool> exportData() async {
    final providers = await _providerRepository.getAllProviders();
    final models = await _modelRepository.getAllModels();
    final sentinels = await _sentinelRepository.getAllSentinels();

    final exportData = {
      'providers': providers.map((p) => p.toJson()).toList(),
      'models': models.map((m) => m.toJson()).toList(),
      'sentinels': sentinels.map((s) => s.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final isDesktop = PlatformUtil.isDesktop;
    final path = isDesktop
        ? await FilePicker.platform.saveFile(
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          )
        : await FilePicker.platform.saveFile(
            bytes: Uint8List.fromList(utf8.encode(jsonString)),
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
    if (path == null) return false;

    // 桌面端 saveFile 只返回路径，需要手动写入文件
    if (isDesktop) {
      final file = File(path);
      await file.writeAsString(jsonString);
    }

    return true;
  }

  /// 从 JSON 文件导入数据
  Future<bool> importData() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择要导入的文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    final file = File(path);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // 先清空本地的 models 和 providers，避免同 ID 不同名导致关联错误
    await _modelRepository.deleteAllModels();
    await _providerRepository.deleteAllProviders();

    // 导入 providers，保留原始 ID
    if (data['providers'] != null) {
      final providersList = data['providers'] as List;
      final providers = providersList
          .map((json) => ProviderEntity.fromJson(json as Map<String, dynamic>))
          .toList();
      await _providerRepository.importProviders(providers);
    }

    // 导入 models，保留原始 ID 和 provider_id
    if (data['models'] != null) {
      final modelsList = data['models'] as List;
      final models = modelsList
          .map((json) => ModelEntity.fromJson(json as Map<String, dynamic>))
          .toList();
      await _modelRepository.importModels(models);
    }

    // 导入 sentinels：同名更新，不同名插入
    if (data['sentinels'] != null) {
      final sentinelsList = data['sentinels'] as List;
      final sentinels = sentinelsList
          .map((json) => SentinelEntity.fromJson(json as Map<String, dynamic>))
          .toList();
      await _sentinelRepository.importSentinels(sentinels);
    }

    // 导入数据可能来自其他实例，本地 chats 的 model_id 可能指向已不存在的模型
    // （chats 无外键约束）。重整悬空引用，使会话立即可用。
    // 注：sentinel_id 同样可能悬空，但本次仅处理 model_id（对应审计症状
    // 'Model not found'）；sentinel 重整作为后续跟进项，暂不实现。
    await reconcileChatModelReferences();

    return true;
  }

  /// 扫描所有会话，将 model_id 指向已不存在模型的会话重置为默认模型。
  /// 默认模型优先取 [chatModelId]（若有效），否则取第一个可用模型。
  @visibleForTesting
  Future<void> reconcileChatModelReferences() async {
    final models = await _modelRepository.getAllModels();
    final validIds = models.map((m) => m.id).whereType<int>().toSet();
    // 没有任何模型可指向：保持 chats 原样，避免写入无效引用。
    if (validIds.isEmpty) return;

    final defaultId = validIds.contains(chatModelId.value)
        ? chatModelId.value
        : validIds.first;

    final chats = await _chatRepository.getAllChats();
    for (final chat in chats) {
      if (!validIds.contains(chat.modelId)) {
        await _chatRepository.updateChat(chat.copyWith(modelId: defaultId));
      }
    }
  }

  Future<bool> resetData() async {
    await Database.instance.reset();
    await clearAllSettings();
    return true;
  }
}
