import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  @Name('dark_mode')
  bool darkMode = false;
  String model = 'gpt-3.5-turbo';
  String proxy = "43.154.15.116:11111";
  @Name('proxy_enabled')
  bool proxyEnabled = true;
  @Name('secret_key')
  String? secretKey;
  String url = 'https://api.openai.com/v1/chat/completions';
}
