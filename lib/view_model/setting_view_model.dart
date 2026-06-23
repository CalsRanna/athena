import 'dart:convert';
import 'dart:io';

import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';

import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/data_migration_service.dart';
import 'package:athena/service/llm_client.dart';
import 'package:athena/util/platform_util.dart';
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
  late final LlmClient _llmClient;
  late final DataMigrationService _dataMigrationService;

  SettingViewModel({
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required LlmClient llmClient,
    required DataMigrationService dataMigrationService,
  }) : _modelRepository = modelRepository,
       _providerRepository = providerRepository,
       _llmClient = llmClient,
       _dataMigrationService = dataMigrationService;

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
    _llmClient.updateRetryConfig(RetryConfig(maxAttempts: maxRetries.value));
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
    _llmClient.updateRetryConfig(RetryConfig(maxAttempts: max));
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
    final json = await _dataMigrationService.exportToJson();
    final isDesktop = PlatformUtil.isDesktop;
    final path = isDesktop
        ? await FilePicker.platform.saveFile(
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          )
        : await FilePicker.platform.saveFile(
            bytes: Uint8List.fromList(utf8.encode(json)),
            dialogTitle: '选择导出位置',
            fileName: 'athena_export.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
    if (path == null) return false;

    if (isDesktop) {
      await File(path).writeAsString(json);
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

    final json = await File(path).readAsString();
    return _dataMigrationService.importFromJson(
      json,
      chatModelId: chatModelId.value,
    );
  }

  /// 扫描所有会话，重整悬空的 model_id 引用
  @visibleForTesting
  Future<void> reconcileChatModelReferences() =>
      _dataMigrationService.reconcileChatModelReferences(chatModelId.value);

  Future<bool> resetData() async {
    await _dataMigrationService.resetDatabase();
    await clearAllSettings();
    return true;
  }
}
