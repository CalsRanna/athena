import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  @Name('dark_mode')
  bool darkMode = false;
  String model = 'gpt-3.5-turbo';
  String proxy = "proxy.cooleio.tech:34311";
  @Name('proxy_enabled')
  bool proxyEnabled = true;
  @Name('secret_key')
  String? secretKey;
  String url = 'https://api.openai.com/v1/chat/completions';
}
