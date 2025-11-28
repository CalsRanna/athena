import 'package:athena/database/database.dart';
import 'package:athena/entity/server_entity.dart';

class ServerRepository {
  Future<List<ServerEntity>> getAllServers() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('servers').get();
    return results.map((r) => ServerEntity.fromJson(r.toMap())).toList();
  }

  Future<ServerEntity?> getServerById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('servers').where('id', id).first();
      return ServerEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<List<ServerEntity>> getEnabledServers() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('servers').where('enabled', 1).get();
    return results.map((r) => ServerEntity.fromJson(r.toMap())).toList();
  }

  Future<int> createServer(ServerEntity server) async {
    var laconic = Database.instance.laconic;
    var json = server.toJson();
    json.remove('id');
    await laconic.table('servers').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateServer(ServerEntity server) async {
    if (server.id == null) return;
    var laconic = Database.instance.laconic;
    var json = server.toJson();
    json.remove('id');
    await laconic.table('servers').where('id', server.id).update(json);
  }

  Future<void> deleteServer(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('servers').where('id', id).delete();
  }

  Future<int> getServersCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('servers').count();
  }

  Future<void> batchCreateServers(List<ServerEntity> servers) async {
    if (servers.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = servers.map((s) {
      var json = s.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('servers').insert(jsonList);
  }

  Future<ServerEntity?> getServerByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('servers').where('name', name).first();
      return ServerEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  /// 导入 servers：同名更新，不同名插入
  Future<void> importServers(List<ServerEntity> servers) async {
    if (servers.isEmpty) return;

    var toInsert = <ServerEntity>[];

    for (var server in servers) {
      var existing = await getServerByName(server.name);
      if (existing != null) {
        // 同名存在，更新
        var updated = server.copyWith(id: existing.id);
        await updateServer(updated);
      } else {
        // 不存在，加入批量插入列表
        toInsert.add(server);
      }
    }

    // 批量插入新的
    if (toInsert.isNotEmpty) {
      await batchCreateServers(toInsert);
    }
  }
}
