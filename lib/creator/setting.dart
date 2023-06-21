import 'package:athena/main.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:isar/isar.dart';

final settingEmitter = Emitter<Setting>(
  (ref, emit) async {
    Setting? setting = await isar.settings.where().findFirst();
    if (setting == null) {
      await isar.writeTxn(() async {
        isar.settings.put(Setting());
      });
      setting = await isar.settings.where().findFirst();
    }
    emit(setting!);
  },
  name: 'settingEmitter',
);
