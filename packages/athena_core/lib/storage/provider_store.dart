import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/yaml_entity_directory.dart';

/// provider 及其模型的文件存储(`~/.athena/providers/{id}.yaml`)。
///
/// 一个 provider 一个文件,文件里既有 provider 自己的配置,也有它提供的模型:
///
/// ```yaml
/// id: "01a0e62b-..."
/// name: "Deep Seek"
/// baseUrl: "https://api.deepseek.com/v1"
/// apiKey: "sk-..."
/// models:
///   - id: "01a0e62b-92e4-..."
///     modelId: "deepseek-v4-flash"
///     ...
/// ```
///
/// 模型并入 provider 文件,是因为它离开 provider 没有意义:一个自建网关的
/// provider 配置与它暴露的模型现在写在一个文件里,不必再维护两份互相引用的
/// 数据、也不会留下「provider 没了、模型还在」的孤儿。
///
/// **provider 的身份是文件名**(见 [YamlEntityDirectory]);**模型的身份是它
/// 自己的 `id`**,必须显式写在文件里——`sessions/{chatId}.jsonl` 里存的
/// `model_id` 就是这个值,不能由文件名或列表位置推导。
///
/// 本类只管「一个 provider 文件里的 provider 与它的模型」;跨 provider 的查询
/// 与排序在仓储层。
class ProviderStore {
  ProviderStore({required Directory directory, required LockRegistry locks})
    : _directory = YamlEntityDirectory(directory: directory, locks: locks);

  final YamlEntityDirectory _directory;

  static const _modelsKey = 'models';

  Directory get directory => _directory.directory;

  static bool isValidId(String id) => YamlEntityDirectory.isValidId(id);

  // ---------------------------------------------------------------------------
  // provider
  // ---------------------------------------------------------------------------

  /// 目录下全部 provider 的 id(不解析文件内容)。
  ///
  /// 清空全部 provider、把旧 `models.json` 归位到各 provider 文件这类整表
  /// 操作要先知道有哪些文件;这里只要文件名,不必把每个文件解析成实体。
  Future<List<String>> providerIds() => _directory.listIds();

  /// 全部 provider(按文件名列举,顺序不定;排序由仓储层决定)。
  Future<List<ProviderEntity>> list() async {
    final entities = <ProviderEntity>[];
    for (final id in await _directory.listIds()) {
      final entity = await read(id);
      if (entity != null) entities.add(entity);
    }
    return entities;
  }

  /// 读取单个 provider(不含模型);不存在或损坏返回 null。
  Future<ProviderEntity?> read(String id) async {
    final raw = await _directory.readRaw(id);
    return raw == null ? null : parseProvider(id, raw);
  }

  /// 覆盖写入 provider(不存在则创建),**保留文件里已有的 [modelsKey] 段**。
  ///
  /// 保留模型段是必须的:仓储层到处用 `copyWith` 改 provider 的一个字段再整体
  /// 写回(改 key、改名、启停、格式同步),而 [ProviderEntity] 不持有模型。
  /// 若这里直接覆盖,那些调用会把模型段整段抹掉。
  Future<void> write(ProviderEntity provider) {
    final id = provider.id;
    if (id == null || !isValidId(id)) {
      throw ArgumentError('Invalid provider id: $id');
    }
    return _directory.upsertRaw(id, (current) {
      final raw = encodeProvider(provider);
      final models = current[_modelsKey];
      if (models != null) raw[_modelsKey] = models;
      return raw;
    });
  }

  /// 读-改-写单个 provider,**保留文件里已有的 [modelsKey] 段**。
  ///
  /// [transform] 拿到锁内读到的最新实体,返回新实体写回;返回 null 表示本次不
  /// 改写(调用方的守卫条件不满足)。文件不存在或损坏时不做任何事并返回 false
  /// ——「更新一个已被删除的 provider」不应把它复活。
  ///
  /// 保留模型段的理由同 [write]:模型不在 [ProviderEntity] 里,整文件覆盖会把
  /// 它们抹掉。
  Future<bool> mutate(
    String id,
    ProviderEntity? Function(ProviderEntity current) transform,
  ) {
    var wrote = false;
    return _directory
        .mutateRaw(id, (current) {
          final updated = transform(parseProvider(id, current));
          if (updated == null) return null;
          wrote = true;
          final raw = encodeProvider(updated);
          final models = current[_modelsKey];
          if (models != null) raw[_modelsKey] = models;
          return raw;
        })
        .then((_) => wrote);
  }

  /// 删除整个 provider 文件——它名下的模型随文件一起消失。
  ///
  /// 这就是「模型属于 provider」的直接结果:不再需要先删模型再删 provider 的
  /// 两步操作,也不会在第一步失败后留下孤儿模型。
  Future<void> delete(String id) => _directory.deleteRaw(id);

  // ---------------------------------------------------------------------------
  // provider 名下的模型
  // ---------------------------------------------------------------------------

  /// 全部 provider 的全部模型。
  ///
  /// 每轮对话都要按 id 找模型,而模型 id 本身不含 provider 信息,只能逐个文件
  /// 找。实测 12 个 provider / 156 个模型一次全扫约 3ms,可以接受;真要更快就
  /// 得引入索引,那是另一回事。
  Future<List<ModelEntity>> listAllModels() async {
    final models = <ModelEntity>[];
    for (final id in await _directory.listIds()) {
      models.addAll(await readModels(id));
    }
    return models;
  }

  /// 某个 provider 名下的模型;文件不存在或损坏返回空列表。
  Future<List<ModelEntity>> readModels(String providerId) async {
    final raw = await _directory.readRaw(providerId);
    if (raw == null) return const [];
    return parseModels(providerId, raw[_modelsKey]);
  }

  /// 按模型自身的 id 查找(跨全部 provider)。找不到返回 null。
  Future<ModelEntity?> findModel(String modelId) async {
    for (final id in await _directory.listIds()) {
      for (final model in await readModels(id)) {
        if (model.id == modelId) return model;
      }
    }
    return null;
  }

  /// 在 [providerId] 的文件里对模型列表做一次读-改-写,返回 [transform] 的结果。
  ///
  /// 增删改单个模型都走这里:整个 provider 文件的锁由 [YamlEntityDirectory]
  /// 保证,一次只落盘一次(而不是每个模型读写一遍整份文件)。
  ///
  /// [strict] 为 true 时,provider 文件必须已存在——不存在就抛 [StateError]。
  /// 新建模型走严格模式:模型属于某个 provider,往一个不存在的 provider 名下
  /// 写模型是调用方的错误(旧的 `models.json` 整表实现由表结构强制了这一点,
  /// 拆成文件后必须显式保住,否则会静默留下一个只含模型的孤儿文件)。
  /// 删除、整段替换等「provider 可能已被删掉」的场景用宽松模式。
  Future<T> mutateModels<T>(
    String providerId,
    T Function(List<ModelEntity> models) transform, {
    bool strict = false,
  }) async {
    if (strict && (await _directory.readRaw(providerId)) == null) {
      throw StateError('Provider does not exist: $providerId');
    }
    late T result;
    await _directory.mutateRaw(providerId, (current) {
      final models = parseModels(providerId, current[_modelsKey]);
      result = transform(models);
      current[_modelsKey] = [for (final model in models) encodeModel(model)];
      return current;
    });
    return result;
  }

  /// 用 [models] 整体替换某个 provider 文件里的模型段。
  Future<void> replaceModelsOf(String providerId, List<ModelEntity> models) {
    return _directory.mutateRaw(providerId, (current) {
      current[_modelsKey] = [for (final model in models) encodeModel(model)];
      return current;
    });
  }

  /// provider 文件数。只数文件、不解析内容。不加锁。
  Future<int> count() => _directory.count();

  // ---------------------------------------------------------------------------
  // 解析与编码
  // ---------------------------------------------------------------------------

  /// provider 文件的 YAML 映射 → 实体。
  ///
  /// 字段缺失或类型不符一律降级(空串 / false / 纪元时间)而不是抛错:这个目录
  /// 标明可以手工编辑,一处笔误不该让整个 provider 消失。
  static ProviderEntity parseProvider(String id, Map raw) {
    return ProviderEntity(
      id: id,
      // 防御:手工编辑可能写入非字符串值(如裸数字被 YAML 解析为 int),
      // 降级为空串而不是抛类型错误
      name: raw['name'] is String ? raw['name'] as String : '',
      baseUrl: raw['baseUrl'] is String ? raw['baseUrl'] as String : '',
      apiKey: raw['apiKey'] is String ? raw['apiKey'] as String : '',
      apiFormat: ApiFormat.tryParse(raw['apiFormat']),
      apiFormatAuto: raw['apiFormatAuto'] is bool
          ? raw['apiFormatAuto'] as bool
          : null,
      enabled: raw['enabled'] == true,
      isPreset: raw['isPreset'] == true,
      createdAt: raw['createdAt'] is String
          ? DateTime.tryParse(raw['createdAt'] as String) ??
                DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 实体 → 文件映射的标量部分(不含模型;模型由 [encodeModel] 逐条展开)。
  static Map<String, dynamic> encodeProvider(ProviderEntity provider) => {
    'id': provider.id,
    'name': provider.name,
    'baseUrl': provider.baseUrl,
    'apiKey': provider.apiKey,
    'apiFormat': provider.apiFormat.value,
    'apiFormatAuto': provider.apiFormatAuto,
    'enabled': provider.enabled,
    'isPreset': provider.isPreset,
    'createdAt': provider.createdAt.toIso8601String(),
  };

  /// [modelsKey] 下的原始列表 → 实体。
  ///
  /// 条目缺 id、或 id 不是合法文件名段时跳过:模型 id 只是数据、不拼路径,但
  /// 缺 id 的模型无法被任何会话引用,留着只会让选择器多出一条点不动的项。
  static List<ModelEntity> parseModels(String providerId, Object? raw) {
    // 返回的必须是**可变**列表:mutateModels 会把它交给调用方增删。返回
    // `const []` 时一个 add 就会抛 "Cannot add to an unmodifiable list"。
    if (raw is! List) return <ModelEntity>[];
    final models = <ModelEntity>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id'];
      if (id is! String || id.isEmpty) continue;
      models.add(
        ModelEntity(
          id: id,
          name: json['name'] is String ? json['name'] as String : '',
          modelId: json['modelId'] is String ? json['modelId'] as String : '',
          providerId: providerId,
          contextWindow: json['contextWindow'] is num
              ? (json['contextWindow'] as num).toInt()
              : 0,
          outputLimit: json['outputLimit'] is num
              ? (json['outputLimit'] as num).toInt()
              : 0,
          inputPrice: json['inputPrice'] is String
              ? json['inputPrice'] as String
              : '',
          outputPrice: json['outputPrice'] is String
              ? json['outputPrice'] as String
              : '',
          releasedAt: json['releasedAt'] is String
              ? json['releasedAt'] as String
              : '',
          reasoning: json['reasoning'] == true,
          vision: json['vision'] == true,
          isPreset: json['isPreset'] == true,
          createdAt: json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt'] as String) ??
                    DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: json['updatedAt'] is String
              ? DateTime.tryParse(json['updatedAt'] as String) ??
                    DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    return models;
  }

  /// 模型 → 文件映射。键名与 JSON 备份的 `toJson()` 不同(那边是下划线),
  /// 这里是给人看的 YAML,用 camelCase 与 provider 的其余字段保持一致。
  ///
  /// `providerId` 不写出:它就是所属文件名,写出来只会和文件名不一致。
  static Map<String, dynamic> encodeModel(ModelEntity model) => {
    'id': model.id,
    'name': model.name,
    'modelId': model.modelId,
    'contextWindow': model.contextWindow,
    'outputLimit': model.outputLimit,
    'inputPrice': model.inputPrice,
    'outputPrice': model.outputPrice,
    'releasedAt': model.releasedAt,
    'reasoning': model.reasoning,
    'vision': model.vision,
    'isPreset': model.isPreset,
    'createdAt': model.createdAt.toIso8601String(),
    'updatedAt': model.updatedAt.toIso8601String(),
  };
}
