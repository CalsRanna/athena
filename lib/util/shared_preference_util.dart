import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceUtil {
  static final instance = SharedPreferenceUtil._();

  final _preferences = SharedPreferences.getInstance();

  final String _keyWindowHeight = 'window_height';
  final String _keyWindowWidth = 'window_width';
  final String _keyChatModelId = 'chat_model_id';
  final String _keyChatNamingModelId = 'chat_naming_model_id';
  final String _keyChatSearchDecisionModelId = 'chat_search_decision_model_id';
  final String _keySentinelMetadataGenerationModelId =
      'sentinel_metadata_generation_model_id';
  final String _keyShortModelId = 'short_model_id';

  SharedPreferenceUtil._();

  Future<int> getChatModelId() async {
    return (await _preferences).getInt(_keyChatModelId) ?? 0;
  }

  Future<int> getChatNamingModelId() async {
    return (await _preferences).getInt(_keyChatNamingModelId) ?? 0;
  }

  Future<int> getChatSearchDecisionModelId() async {
    return (await _preferences).getInt(_keyChatSearchDecisionModelId) ?? 0;
  }

  Future<int> getSentinelMetadataGenerationModelId() async {
    return (await _preferences).getInt(_keySentinelMetadataGenerationModelId) ??
        0;
  }

  Future<int> getShortModelId() async {
    return (await _preferences).getInt(_keyShortModelId) ?? 0;
  }

  Future<double> getWindowHeight() async {
    return (await _preferences).getDouble(_keyWindowHeight) ?? 720.0;
  }

  Future<double> getWindowWidth() async {
    return (await _preferences).getDouble(_keyWindowWidth) ?? 960.0;
  }

  Future<void> setChatModelId(int modelId) async {
    await (await _preferences).setInt(_keyChatModelId, modelId);
  }

  Future<void> setChatNamingModelId(int modelId) async {
    await (await _preferences).setInt(_keyChatNamingModelId, modelId);
  }

  Future<void> setChatSearchDecisionModelId(int modelId) async {
    await (await _preferences).setInt(_keyChatSearchDecisionModelId, modelId);
  }

  Future<void> setSentinelMetadataGenerationModelId(int modelId) async {
    await (await _preferences).setInt(
      _keySentinelMetadataGenerationModelId,
      modelId,
    );
  }

  Future<void> setShortModelId(int modelId) async {
    await (await _preferences).setInt(_keyShortModelId, modelId);
  }

  Future<void> setWindowHeight(double height) async {
    await (await _preferences).setDouble(_keyWindowHeight, height);
  }

  Future<void> setWindowWidth(double width) async {
    await (await _preferences).setDouble(_keyWindowWidth, width);
  }
}
