import 'package:athena/api/manager.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model.g.dart';

@riverpod
class ModelNotifier extends _$ModelNotifier {
  @override
  Future<Model> build(String value) async {
    var model = await isar.models.filter().valueEqualTo(value).findFirst();
    if (model != null) return model;
    var setting = await ref.watch(settingNotifierProvider.future);
    model = await isar.models.filter().valueEqualTo(setting.model).findFirst();
    if (model != null) return model;
    var models = await ref.watch(modelsNotifierProvider.future);
    return models.first;
  }
}

@riverpod
class ModelsNotifier extends _$ModelsNotifier {
  @override
  Future<List<Model>> build() async {
    final models = await isar.models.where().findAll();
    if (models.isNotEmpty) return _sort(models);
    final remoteModels = await ManagerApi().getModels();
    isar.writeTxn(() async {
      isar.models.putAll(remoteModels);
    });
    return _sort(remoteModels);
  }

  Future<void> deleteModel(Model model) async {
    await isar.writeTxn(() async {
      await isar.models.delete(model.id);
    });
    ref.invalidateSelf();
    var setting = await ref.read(settingNotifierProvider.future);
    if (setting.model == model.value) {
      var notifier = ref.read(settingNotifierProvider.notifier);
      notifier.updateModel('');
    }
  }

  Future<void> getModels() async {
    final remoteModels = await ManagerApi().getModels();
    for (final model in remoteModels) {
      final queryBuilder = isar.models.filter().valueEqualTo(model.value);
      final exist = await queryBuilder.findFirst();
      if (exist == null) {
        isar.writeTxn(() async {
          isar.models.put(model);
        });
      }
    }
    ref.invalidateSelf();
    final setting = await ref.read(settingNotifierProvider.future);
    if (setting.model.isNotEmpty) return;
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateModel(remoteModels.first.value);
  }

  Future<void> storeModel(Model model) async {
    var models = await future;
    if (models.any((m) => m.value == model.value)) {
      throw Exception('Model already exist');
    }
    await isar.writeTxn(() async {
      await isar.models.put(model);
    });
    ref.invalidateSelf();
  }

  Future<void> updateModel(Model model) async {
    await isar.writeTxn(() async {
      await isar.models.put(model);
    });
    ref.invalidateSelf();
  }

  List<Model> _sort(List<Model> models) {
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}
