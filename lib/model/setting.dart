import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  String url = 'https://api.openai.com/v1/chat/completions';
  String model = 'gpt-3.5-turbo';
  @Name('secret_key')
  String? secretKey;
  @Name('dark-mode')
  bool darkMode = false;
}
