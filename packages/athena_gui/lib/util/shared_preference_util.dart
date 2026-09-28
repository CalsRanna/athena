import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceUtil {
  static final instance = SharedPreferenceUtil._();

  final _preferences = SharedPreferences.getInstance();

  final String _keyWindowHeight = 'window_height';
  final String _keyWindowWidth = 'window_width';
  final String _keyChatModelId = 'chat_model_id';
  final String _keyChatNamingModelId = 'chat_naming_model_id';
  final String _keySentinelMetadataGenerationModelId =
      'sentinel_metadata_generation_model_id';

  SharedPreferenceUtil._();

  Future<String> getChatModelId() async {
    return (await _preferences).getString(_keyChatModelId) ?? '';
  }

  Future<String> getChatNamingModelId() async {
    return (await _preferences).getString(_keyChatNamingModelId) ?? '';
  }

  Future<String> getSentinelMetadataGenerationModelId() async {
    return (await _preferences).getString(
          _keySentinelMetadataGenerationModelId,
        ) ??
        '';
  }

  Future<double> getWindowHeight() async {
    return (await _preferences).getDouble(_keyWindowHeight) ?? 720.0;
  }

  Future<double> getWindowWidth() async {
    return (await _preferences).getDouble(_keyWindowWidth) ?? 1080.0;
  }

  Future<void> setChatModelId(String modelId) async {
    await (await _preferences).setString(_keyChatModelId, modelId);
  }

  Future<void> setChatNamingModelId(String modelId) async {
    await (await _preferences).setString(_keyChatNamingModelId, modelId);
  }

  Future<void> setSentinelMetadataGenerationModelId(String modelId) async {
    await (await _preferences).setString(
      _keySentinelMetadataGenerationModelId,
      modelId,
    );
  }

  Future<void> setWindowHeight(double height) async {
    await (await _preferences).setDouble(_keyWindowHeight, height);
  }

  Future<void> setWindowWidth(double width) async {
    await (await _preferences).setDouble(_keyWindowWidth, width);
  }
}
