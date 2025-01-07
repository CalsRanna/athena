import 'package:athena/api/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/util/proxy.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting.g.dart';

@riverpod
class SettingNotifier extends _$SettingNotifier {
  @override
  Future<Setting> build() async {
    final setting = await isar.settings.where().findFirst();
    ProxyConfig.instance.key = setting?.key ?? '';
    ProxyConfig.instance.url = setting?.url ?? '';
    return setting ?? Setting();
  }

  Future<String> connect() async {
    var previousState = await future;
    try {
      var message = Message()
        ..role = 'user'
        ..content = 'Hi';
      var tokens = ChatApi().getCompletion(
        messages: [message],
        model: previousState.model,
      );
      var result = '';
      await for (final token in tokens) {
        result += token;
      }
      if (result.isEmpty) return 'Failed';
      return 'Succeed';
    } catch (error) {
      return 'Failed';
    }
  }

  Future<void> toggleLatex() async {
    final setting = await future;
    setting.latex = !setting.latex;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> toggleMode() async {
    final setting = await future;
    setting.darkMode = !setting.darkMode;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> updateKey(String key) async {
    final setting = await future;
    setting.key = key;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> updateModel(String model) async {
    final setting = await future;
    setting.model = model;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> updateUrl(String url) async {
    final setting = await future;
    setting.url = url;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }
}
