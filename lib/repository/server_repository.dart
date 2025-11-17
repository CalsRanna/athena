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
}
