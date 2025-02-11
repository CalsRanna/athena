import 'package:athena/provider/provider.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model.g.dart';

@riverpod
class ModelNotifier extends _$ModelNotifier {
  @override
  Future<Model> build(int id) async {
    var model = await isar.models.filter().idEqualTo(id).findFirst();
    if (model != null) return model;
    return Model();
  }
}

@riverpod
class EnabledModelsForNotifier extends _$EnabledModelsForNotifier {
  @override
  //不能使用Provider作为参数，有冲突
  Future<List<Model>> build(int providerId) async {
    var builder = isar.models.filter().providerIdEqualTo(providerId);
    builder = builder.enabledEqualTo(true);
    final models = await builder.findAll();
    return _sort(models);
  }

  List<Model> _sort(List<Model> models) {
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}

@riverpod
class ModelsForNotifier extends _$ModelsForNotifier {
  @override
  //不能使用Provider作为参数，有冲突
  Future<List<Model>> build(int providerId) async {
    var builder = isar.models.filter().providerIdEqualTo(providerId);
    final models = await builder.findAll();
    return _sort(models);
  }

  Future<void> storeModel(Model model) async {
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

  Future<void> deleteModel(Model model) async {
    await isar.writeTxn(() async {
      await isar.models.delete(model.id);
    });
    ref.invalidateSelf();
  }

  Future<void> toggleModel(Model model) async {
    var copiedModel = model.copyWith(enabled: !model.enabled);
    await isar.writeTxn(() async {
      await isar.models.put(copiedModel);
    });
    ref.invalidateSelf();
  }

  List<Model> _sort(List<Model> models) {
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}

@riverpod
class GroupedEnabledModelsNotifier extends _$GroupedEnabledModelsNotifier {
  @override
  Future<Map<String, List<Model>>> build() async {
    var providers = await ref.watch(enabledProvidersNotifierProvider.future);
    Map<String, List<Model>> result = {};
    for (var provider in providers) {
      var models =
          await ref.watch(enabledModelsForNotifierProvider(provider.id).future);
      if (models.isEmpty) continue;
      result[provider.name] = models;
    }
    return result;
  }
}

// @riverpod
// class ModelsNotifier extends _$ModelsNotifier {
//   @override
//   Future<List<Model>> build() async {
//     final models = await isar.models.where().findAll();
//     if (models.isNotEmpty) return _sort(models);
//     final remoteModels = await ManagerApi().getModels();
//     isar.writeTxn(() async {
//       isar.models.putAll(remoteModels);
//     });
//     return _sort(remoteModels);
//   }

//   Future<void> deleteModel(Model model) async {
//     await isar.writeTxn(() async {
//       await isar.models.delete(model.id);
//     });
//     ref.invalidateSelf();
//     var setting = await ref.read(settingNotifierProvider.future);
//     if (setting.model == model.value) {
//       var notifier = ref.read(settingNotifierProvider.notifier);
//       notifier.updateModel('');
//     }
//   }

//   Future<void> getModels() async {
//     final remoteModels = await ManagerApi().getModels();
//     for (final model in remoteModels) {
//       final queryBuilder = isar.models.filter().valueEqualTo(model.value);
//       final exist = await queryBuilder.findFirst();
//       if (exist == null) {
//         isar.writeTxn(() async {
//           isar.models.put(model);
//         });
//       }
//     }
//     ref.invalidateSelf();
//     final setting = await ref.read(settingNotifierProvider.future);
//     if (setting.model.isNotEmpty) return;
//     final notifier = ref.read(settingNotifierProvider.notifier);
//     notifier.updateModel(remoteModels.first.value);
//   }

//   Future<void> storeModel(Model model) async {
//     var models = await future;
//     if (models.any((m) => m.value == model.value)) {
//       throw Exception('Model already exist');
//     }
//     await isar.writeTxn(() async {
//       await isar.models.put(model);
//     });
//     ref.invalidateSelf();
//   }

//   Future<void> updateModel(Model model) async {
//     await isar.writeTxn(() async {
//       await isar.models.put(model);
//     });
//     ref.invalidateSelf();
//   }

//   List<Model> _sort(List<Model> models) {
//     models.sort((a, b) => a.name.compareTo(b.name));
//     return models;
//   }
// }
