import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  @Name('dark_mode')
  bool darkMode = false;
  double frequencePenalty = 0;
  @Name('max_tokens')
  int maxTokens = 4096;
  String model = 'gpt-3.5-turbo';
  int n = 1;
  @Name('PRESENCE_PENALTY')
  double presencePenalty = 0;
  String proxy = "43.154.15.116:11111";
  @Name('proxy_enabled')
  bool proxyEnabled = true;
  @Name('secret_key')
  String? secretKey;
  bool stream = true;
  double temperature = 1;
  @Name('top_p')
  double topP = 1;
  String url = 'https://api.openai.com/v1/chat/completions';
}
