import 'package:signals/signals.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingViewModel 使用 SharedPreferences 管理应用设置
/// 不依赖数据库，所有设置都存储在本地偏好设置中
class SettingViewModel {
  // Window 尺寸
  final windowHeight = signal(720.0);
  final windowWidth = signal(960.0);

  // 模型 ID 设置
  final chatModelId = signal(0);
  final chatNamingModelId = signal(0);
  final chatSearchDecisionModelId = signal(0);
  final sentinelMetadataGenerationModelId = signal(0);
  final shortModelId = signal(0);

  final isLoading = signal(false);
  final error = signal<String?>(null);

  // SharedPreferences keys
  static const String _keyWindowHeight = 'window_height';
  static const String _keyWindowWidth = 'window_width';
  static const String _keyChatModelId = 'chat_model_id';
  static const String _keyChatNamingModelId = 'chat_naming_model_id';
  static const String _keyChatSearchDecisionModelId = 'chat_search_decision_model_id';
  static const String _keySentinelMetadataGenerationModelId = 'sentinel_metadata_generation_model_id';
  static const String _keyShortModelId = 'short_model_id';

  /// 加载所有设置
  Future<void> loadSettings() async {
    isLoading.value = true;
    error.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();

      windowHeight.value = prefs.getDouble(_keyWindowHeight) ?? 720.0;
      windowWidth.value = prefs.getDouble(_keyWindowWidth) ?? 960.0;
      chatModelId.value = prefs.getInt(_keyChatModelId) ?? 0;
      chatNamingModelId.value = prefs.getInt(_keyChatNamingModelId) ?? 0;
      chatSearchDecisionModelId.value = prefs.getInt(_keyChatSearchDecisionModelId) ?? 0;
      sentinelMetadataGenerationModelId.value = prefs.getInt(_keySentinelMetadataGenerationModelId) ?? 0;
      shortModelId.value = prefs.getInt(_keyShortModelId) ?? 0;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 更新窗口尺寸
  Future<void> updateWindowSize(double height, double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyWindowHeight, height);
      await prefs.setDouble(_keyWindowWidth, width);

      windowHeight.value = height;
      windowWidth.value = width;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新聊天模型 ID
  Future<void> updateChatModelId(int modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyChatModelId, modelId);
      chatModelId.value = modelId;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新聊天命名模型 ID
  Future<void> updateChatNamingModelId(int modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyChatNamingModelId, modelId);
      chatNamingModelId.value = modelId;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新搜索决策模型 ID
  Future<void> updateChatSearchDecisionModelId(int modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyChatSearchDecisionModelId, modelId);
      chatSearchDecisionModelId.value = modelId;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新 Sentinel 元数据生成模型 ID
  Future<void> updateSentinelMetadataGenerationModelId(int modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySentinelMetadataGenerationModelId, modelId);
      sentinelMetadataGenerationModelId.value = modelId;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新短模型 ID
  Future<void> updateShortModelId(int modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyShortModelId, modelId);
      shortModelId.value = modelId;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 清除所有设置（恢复默认）
  Future<void> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await loadSettings(); // 重新加载默认值
    } catch (e) {
      error.value = e.toString();
    }
  }

  void dispose() {
    windowHeight.dispose();
    windowWidth.dispose();
    chatModelId.dispose();
    chatNamingModelId.dispose();
    chatSearchDecisionModelId.dispose();
    sentinelMetadataGenerationModelId.dispose();
    shortModelId.dispose();
    isLoading.dispose();
    error.dispose();
  }
}
