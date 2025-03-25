import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting.g.dart';

@Riverpod(keepAlive: true)
class DeveloperModeNotifier extends _$DeveloperModeNotifier {
  @override
  bool build() => false;

  void open() {
    state = true;
  }
}

@riverpod
class SettingNotifier extends _$SettingNotifier {
  @override
  Future<Setting> build() async {
    final setting = await isar.settings.where().findFirst();
    return setting ?? Setting();
  }
}
