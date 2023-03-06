import 'package:athena/creator/global.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:isar/isar.dart';

final settingEmitter = Emitter<Setting>(
  (ref, emit) async {
    final isar = ref.watch(isarEmitter.asyncData).data;
    Setting? setting = await isar?.settings.where().findFirst();
    if (setting == null) {
      await isar?.writeTxn(() async {
        isar.settings.put(Setting());
      });
      setting = await isar?.settings.where().findFirst();
    }
    emit(setting!);
  },
  name: 'settingEmitter',
);
