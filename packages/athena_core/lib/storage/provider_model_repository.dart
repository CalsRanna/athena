import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/provider_store.dart';

/// ModelRepository 的实现:模型存在它所属 provider 的文件里
/// (`providers/{providerId}.yaml` 的 `models:` 段)。
///
/// 取代旧的 `models.json` 整表数组:模型离开 provider 没有意义,放在一起之后
/// 删 provider 就是删文件(模型随它消失,不再需要先删模型的两步操作),自建
/// 网关的配置与模型也写在同一处。
///
/// **每次写入只落盘一次**。旧实现是「读整个 models.json → 改 → 写回整个
/// models.json」,而目录同步对每个模型各调一次 create/update,一次同步就是
/// 几百次全量文件读写;这里整批模型在同一个 provider 文件里一次算完、一次落盘。
///
/// 模型自己的 `id` 必须显式存在(不能像 provider 那样由文件名推导):
/// `sessions/{chatId}.jsonl` 里存的 `model_id` 引用它。
class ProviderModelRepository implements ModelRepository {
  ProviderModelRepository({
    required ProviderStore store,
    IdGenerator idGenerator = const IdGenerator(),
  }) : _store = store,
       _idGenerator = idGenerator;

  final ProviderStore _store;
  final IdGenerator _idGenerator;

  @override
  Future<List<ModelEntity>> getAllModels() => _store.listAllModels();

  @override
  Future<ModelEntity?> getModelById(String id) => _store.findModel(id);

  @override
  Future<List<ModelEntity>> getModelsByProviderId(String providerId) =>
      _store.readModels(providerId);

  @override
  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    String providerId,
  ) async {
    for (final model in await _store.readModels(providerId)) {
      if (model.name == name) return model;
    }
    return null;
  }

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    String providerId,
  ) async {
    for (final model in await _store.readModels(providerId)) {
      if (model.modelId == modelId) return model;
    }
    return null;
  }

  @override
  Future<String> createModel(ModelEntity model) {
    final id = _idGenerator.next();
    return _append(model.copyWith(id: id)).then((_) => id);
  }

  @override
  Future<void> updateModel(ModelEntity model) async {
    final id = model.id;
    if (id == null) return;
    await _store.mutateModels(model.providerId, (models) {
      final index = models.indexWhere((m) => m.id == id);
      if (index >= 0) {
        models[index] = model;
      } else {
        // provider 文件在、模型不在(手工编辑删掉了):补回去,与旧的
        // 「整表替换式更新」语义一致
        models.add(model);
      }
    });
  }

  @override
  Future<void> deleteModel(String id) async {
    final model = await _store.findModel(id);
    if (model == null) return;
    await _store.mutateModels(model.providerId, (models) {
      models.removeWhere((m) => m.id == id);
    });
  }

  @override
  Future<void> deleteModelsByProviderId(String providerId) {
    return _store.replaceModelsOf(providerId, const []);
  }

  @override
  Future<int> getModelsCount() async => (await getAllModels()).length;

  @override
  Future<void> batchCreateModels(List<ModelEntity> models) async {
    // 按 provider 分组:同一份 provider 文件只读写一次,而不是每个模型一次
    final grouped = <String, List<ModelEntity>>{};
    for (final model in models) {
      final id = model.id ?? _idGenerator.next();
      grouped
          .putIfAbsent(model.providerId, () => [])
          .add(model.copyWith(id: id));
    }
    for (final entry in grouped.entries) {
      await _store.mutateModels(entry.key, (existing) {
        existing.addAll(entry.value);
      });
    }
  }

  @override
  Future<void> deleteAllModels() async {
    for (final providerId in await _store.providerIds()) {
      await _store.replaceModelsOf(providerId, const []);
    }
  }

  @override
  Future<void> importModels(List<ModelEntity> models) async {
    // 按 provider 分组,每个 provider 的文件写一次
    final grouped = <String, List<ModelEntity>>{};
    for (final model in models) {
      grouped.putIfAbsent(model.providerId, () => []).add(model);
    }
    for (final providerId in await _store.providerIds()) {
      await _store.replaceModelsOf(
        providerId,
        grouped.remove(providerId) ?? [],
      );
    }
  }

  /// 追加一个模型到它所属 provider 的文件。
  ///
  /// 严格模式:provider 不存在就抛错,而不是凭空造一个只含模型的孤儿文件。
  Future<void> _append(ModelEntity model) {
    return _store.mutateModels(model.providerId, (models) {
      models.add(model);
    }, strict: true);
  }
}
