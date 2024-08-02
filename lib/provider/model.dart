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
}
