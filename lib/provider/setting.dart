import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting.g.dart';

@riverpod
class SettingNotifier extends _$SettingNotifier {
  @override
  Future<Setting> build() async {
    final setting = await isar.settings.where().findFirst();
    return setting ?? Setting();
  }

  Future<void> updateKey(String key) async {
    final setting = await future;
    // setting.key = key;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> updateModel(String model) async {
    final setting = await future;
    // setting.model = model;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> updateUrl(String url) async {
    final setting = await future;
    // setting.url = url;
    state = AsyncData(setting);
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
  }

  Future<void> store({String? key, String? url}) async {
    final setting = await future;
    // if (key != null) setting.key = key;
    // if (url != null) setting.url = url;
    await isar.writeTxn(() async {
      await isar.settings.put(setting);
    });
    ref.invalidateSelf();
  }
}
