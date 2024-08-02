import 'package:athena/api/manager.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model.g.dart';

@riverpod
class ModelsNotifier extends _$ModelsNotifier {
  @override
  Future<List<Model>> build() async {
    final models = await isar.models.where().findAll();
    if (models.isEmpty) {
      final remoteModels = await ManagerApi().getModels();
      isar.writeTxn(() async {
        isar.models.putAll(remoteModels);
      });
      return remoteModels;
    }
    return models;
  }

  Future<void> getModels() async {
    final models = await ManagerApi().getModels();
    state = AsyncData([...models]);
    for (final model in models) {
      final queryBuilder = isar.models.filter().valueEqualTo(model.value);
      final exist = await queryBuilder.findFirst();
      if (exist == null) {
        isar.writeTxn(() async {
          isar.models.put(model);
        });
      }
    }
  }
}
