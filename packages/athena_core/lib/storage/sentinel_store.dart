import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/yaml_entity_directory.dart';

/// 角色的文件存储(`~/.athena/sentinels/{id}.yaml`),一个角色一个文件。
///
/// 取代旧的 `sentinels.json` 整表数组:那个实现一次 YAML 语法错误就让整个角色
/// 列表读成空、下次写入把全部角色抹掉;拆开之后一个坏文件只影响它自己,手工
/// 新增/编辑一个角色也不必动含全部角色的文件。
///
/// **角色 id 必须稳定**:`sessions/{chatId}.jsonl` 里的 `sentinelId` 与
/// `sentinels/by-id/{id}/history/` 的快照目录都引用它。所以角色**改名字不能换
/// 文件**——与 provider 一致但理由更强,改名必须原地改写而不是改名文件。
class SentinelStore {
  SentinelStore({required Directory directory})
    : _directory = YamlEntityDirectory(directory: directory);

  final YamlEntityDirectory _directory;

  Directory get directory => _directory.directory;

  static bool isValidId(String id) => YamlEntityDirectory.isValidId(id);

  /// 全部角色(按文件名列举,顺序不定)。
  Future<List<SentinelEntity>> list() async {
    final entities = <SentinelEntity>[];
    for (final id in await _directory.listIds()) {
      final entity = await read(id);
      if (entity != null) entities.add(entity);
    }
    return entities;
  }

  /// 读取单个角色;不存在或损坏返回 null。
  Future<SentinelEntity?> read(String id) async {
    final raw = await _directory.readRaw(id);
    return raw == null ? null : parse(id, raw);
  }

  /// 覆盖写入(不存在则创建)。
  Future<void> write(SentinelEntity sentinel) {
    final id = sentinel.id;
    if (id == null || !isValidId(id)) {
      throw ArgumentError('Invalid sentinel id: $id');
    }
    return _directory.writeRaw(id, encode(sentinel));
  }

  /// 读-改-写单个角色;文件不存在时不做任何事(不复活已删除的角色)。
  Future<bool> mutate(
    String id,
    SentinelEntity? Function(SentinelEntity current) transform,
  ) async {
    var wrote = false;
    await _directory.mutateRaw(id, (current) {
      final updated = transform(parse(id, current));
      if (updated == null) return null;
      wrote = true;
      return encode(updated);
    });
    return wrote;
  }

  /// 删除单个角色(不存在视为成功)。
  Future<void> delete(String id) => _directory.deleteRaw(id);

  /// 整目录替换为 [sentinels](导入用)。每个实体的 id 必须非空。
  Future<void> replaceAll(List<SentinelEntity> sentinels) {
    for (final sentinel in sentinels) {
      if (sentinel.id == null || !isValidId(sentinel.id!)) {
        throw ArgumentError('Invalid sentinel id: ${sentinel.id}');
      }
    }
    return _directory.replaceAllRaw([
      for (final sentinel in sentinels) (sentinel.id!, encode(sentinel)),
    ]);
  }

  /// 角色文件数。只数文件、不解析内容;不加锁。
  Future<int> count() => _directory.count();

  /// 角色文件的 YAML 映射 → 实体。字段缺失按空串 / false 降级(手工编辑容错)。
  static SentinelEntity parse(String id, Map raw) {
    return SentinelEntity(
      id: id,
      name: raw['name'] is String ? raw['name'] as String : '',
      description: raw['description'] is String
          ? raw['description'] as String
          : '',
      prompt: raw['prompt'] is String ? raw['prompt'] as String : '',
      tags: raw['tags'] is String ? raw['tags'] as String : '',
      isPreset: raw['isPreset'] == true,
    );
  }

  static Map<String, dynamic> encode(SentinelEntity sentinel) => {
    'id': sentinel.id,
    'name': sentinel.name,
    'description': sentinel.description,
    'prompt': sentinel.prompt,
    'tags': sentinel.tags,
    'isPreset': sentinel.isPreset,
  };
}
