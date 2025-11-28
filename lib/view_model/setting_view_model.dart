import 'dart:convert';
import 'dart:io';

import 'package:athena/database/database.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/util/shared_preference_util.dart';
import 'package:file_picker/file_picker.dart';
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
  static const String _keyChatSearchDecisionModelId =
      'chat_search_decision_model_id';
  static const String _keySentinelMetadataGenerationModelId =
      'sentinel_metadata_generation_model_id';
  static const String _keyShortModelId = 'short_model_id';
  // Window 尺寸
  final windowHeight = signal(720.0);
  final windowWidth = signal(960.0);
  // 模型 ID 设置
  final chatModelId = signal(0);
  final chatNamingModelId = signal(0);
  final chatSearchDecisionModelId = signal(0);
  final sentinelMetadataGenerationModelId = signal(0);
  final shortModelId = signal(0);
  final chatModel = signal<ModelEntity?>(null);
  final chatNamingModel = signal<ModelEntity?>(null);
  final chatSearchDecisionModel = signal<ModelEntity?>(null);

  final sentinelMetadataGenerationModel = signal<ModelEntity?>(null);
  final shortModel = signal<ModelEntity?>(null);
  final chatModelProvider = signal<ProviderEntity?>(null);
  final chatNamingModelProvider = signal<ProviderEntity?>(null);
  final chatSearchDecisionModelProvider = signal<ProviderEntity?>(null);
  final sentinelMetadataGenerationModelProvider = signal<ProviderEntity?>(null);
  final shortModelProvider = signal<ProviderEntity?>(null);

  final _modelRepository = ModelRepository();
  final _providerRepository = ProviderRepository();
  final _sentinelRepository = SentinelRepository();

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
    chatSearchDecisionModelId.value =
        instance.getInt(_keyChatSearchDecisionModelId) ?? 0;
    sentinelMetadataGenerationModelId.value =
        instance.getInt(_keySentinelMetadataGenerationModelId) ?? 0;
    shortModelId.value = instance.getInt(_keyShortModelId) ?? 0;
    chatModel.value = await _modelRepository.getModelById(chatModelId.value);
    chatNamingModel.value = await _modelRepository.getModelById(
      chatNamingModelId.value,
    );
    chatSearchDecisionModel.value = await _modelRepository.getModelById(
      chatSearchDecisionModelId.value,
    );
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      sentinelMetadataGenerationModelId.value,
    );
    shortModel.value = await _modelRepository.getModelById(shortModelId.value);
    chatModelProvider.value = await _providerRepository.getProviderById(
      chatModelId.value,
    );
    chatNamingModelProvider.value = await _providerRepository.getProviderById(
      chatNamingModelId.value,
    );
    chatSearchDecisionModelProvider.value = await _providerRepository
        .getProviderById(chatSearchDecisionModelId.value);
    sentinelMetadataGenerationModelProvider.value = await _providerRepository
        .getProviderById(sentinelMetadataGenerationModelId.value);
    shortModelProvider.value = await _providerRepository.getProviderById(
      shortModelId.value,
    );
  }

  /// 更新聊天模型 ID
  Future<void> updateChatModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyChatModelId, modelId);
    chatModelId.value = modelId;
    chatModel.value = await _modelRepository.getModelById(modelId);
    chatModelProvider.value = await _providerRepository.getProviderById(
      modelId,
    );
  }

  /// 更新聊天命名模型 ID
  Future<void> updateChatNamingModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyChatNamingModelId, modelId);
    chatNamingModelId.value = modelId;
    chatNamingModel.value = await _modelRepository.getModelById(modelId);
    chatNamingModelProvider.value = await _providerRepository.getProviderById(
      modelId,
    );
  }

  /// 更新搜索决策模型 ID
  Future<void> updateChatSearchDecisionModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyChatSearchDecisionModelId, modelId);
    chatSearchDecisionModelId.value = modelId;
    chatSearchDecisionModelProvider.value = await _providerRepository
        .getProviderById(modelId);
  }

  /// 更新 Sentinel 元数据生成模型 ID
  Future<void> updateSentinelMetadataGenerationModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keySentinelMetadataGenerationModelId, modelId);
    sentinelMetadataGenerationModelId.value = modelId;
    sentinelMetadataGenerationModel.value = await _modelRepository.getModelById(
      modelId,
    );
    sentinelMetadataGenerationModelProvider.value = await _providerRepository
        .getProviderById(modelId);
  }

  /// 更新短模型 ID
  Future<void> updateShortModelId(int modelId) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setInt(_keyShortModelId, modelId);
    shortModelId.value = modelId;
    shortModel.value = await _modelRepository.getModelById(modelId);
    shortModelProvider.value = await _providerRepository.getProviderById(
      modelId,
    );
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
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '选择导出位置',
      fileName: 'athena_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return false;

    final providers = await _providerRepository.getAllProviders();
    final models = await _modelRepository.getAllModels();
    final sentinels = await _sentinelRepository.getAllSentinels();

    final exportData = {
      'export_time': DateTime.now().toIso8601String(),
      'providers': providers.map((p) => p.toJson()).toList(),
      'models': models.map((m) => m.toJson()).toList(),
      'sentinels': sentinels.map((s) => s.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final file = File(path);
    await file.writeAsString(jsonString);
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

    // 导入 providers：同名更新，不同名插入
    if (data['providers'] != null) {
      final providersList = data['providers'] as List;
      final providers = providersList
          .map((json) => ProviderEntity.fromJson(json as Map<String, dynamic>))
          .toList();
      await _providerRepository.importProviders(providers);
    }

    // 导入 models：同名同 provider 更新，否则插入
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

    return true;
  }

  Future<bool> resetData() async {
    await Database.instance.reset();
    await clearAllSettings();
    return true;
  }
}
