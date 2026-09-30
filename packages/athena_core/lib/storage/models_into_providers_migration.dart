import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/provider_store.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 一次性升级:把 `models.json` 按 `provider_id` 分发进各 provider 文件的
/// `models:` 段,然后删除 `models.json`(改名成 `models.json.migrated` 留档)。
///
/// 必须跑在 [ProviderFilesMigration] 之后:那时 provider 已经是一个一个文件,
/// 模型才知道该写进哪个文件。两者都依赖 `StorageIdMigration` 已完成(provider
/// 与模型的 id 都已是 UUID,`provider_id` 才指得准)。
///
/// 顺序上与 provider 迁移一致:先备份、再逐文件写入、最后才让 `models.json`
/// 退场。中断在任何一步,重跑都从「provider 文件可能已带上一部分模型」继续
/// ——按 `provider_id` 分组后整段覆盖,重复执行结果相同。
///
/// `models.json` 不直接删除而是改名:出问题还能把原始数据找回来。它此后不再
/// 被读取,下次启动也不会再触发本迁移(标记已落盘)。
class ModelsIntoProvidersMigration {
  ModelsIntoProvidersMigration({
    required Directory root,
    required File modelsFile,
    required ProviderStore providerStore,
  }) : _root = root,
       _modelsFile = modelsFile,
       _providerStore = providerStore;

  static const version = 1;

  final Directory _root;
  final File _modelsFile;
  final ProviderStore _providerStore;

  File get _marker =>
      File(p.join(_providerStore.directory.path, '.models-version'));
  File get _lockFile =>
      File(p.join(_root.path, '.models-into-providers-migration.lock'));

  Future<void> run() {
    return withFileLock(_lockFile, () async {
      if (await _marker.exists()) return;
      if (!await _modelsFile.exists()) {
        // 新装(还没有 models.json)或已迁移过:落标记即可
        await _writeMarker();
        return;
      }

      final models = await _readModels();
      final grouped = <String, List<ModelEntity>>{};
      for (final model in models) {
        grouped.putIfAbsent(model.providerId, () => []).add(model);
      }

      // provider 已不存在的模型无法归位:写进任何文件都是在制造孤儿。
      // 保留 models.json 的备份,让用户/后续迁移还能看到它们。
      final known = (await _providerStore.providerIds()).toSet();
      final orphaned = grouped.keys.where((id) => !known.contains(id)).toList();
      for (final providerId in orphaned) {
        grouped.remove(providerId);
      }

      for (final entry in grouped.entries) {
        await _providerStore.replaceModelsOf(entry.key, entry.value);
      }

      await _modelsFile.rename('${_modelsFile.path}.migrated');
      await _writeMarker();
      LoggerUtil.i(
        'Model files: moved ${models.length} models into '
        '${_providerStore.directory.path}'
        '${orphaned.isEmpty ? '' : ' (${orphaned.length} providers unknown, kept in ${_modelsFile.path}.migrated)'}',
      );
    });
  }

  /// `models.json` 的 JSON 数组 → 实体。
  ///
  /// 文件损坏时保留原文件并抛错中止:整表没了还继续跑,会写出一堆空 models
  /// 段并把唯一的数据源改名退场,那就是真的丢数据了。
  Future<List<ModelEntity>> _readModels() async {
    final raw = jsonDecode(await _modelsFile.readAsString());
    if (raw is! List) {
      throw const FormatException('models.json is not a JSON array');
    }
    return [
      for (final item in raw)
        if (item is Map) ModelEntity.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> _writeMarker() async {
    await atomicWriteString(_marker, 'version: $version\n');
  }
}
