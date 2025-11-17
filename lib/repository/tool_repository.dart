import 'package:athena/database/database.dart';
import 'package:athena/entity/tool_entity.dart';

class ToolRepository {
  Future<List<ToolEntity>> getAllTools() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('tools').get();
    return results.map((r) => ToolEntity.fromJson(r.toMap())).toList();
  }

  Future<ToolEntity?> getToolById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('tools').where('id', id).first();
      return ToolEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<ToolEntity?> getToolByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('tools').where('name', name).first();
      return ToolEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<int> createTool(ToolEntity tool) async {
    var laconic = Database.instance.laconic;
    var json = tool.toJson();
    json.remove('id');
    await laconic.table('tools').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateTool(ToolEntity tool) async {
    if (tool.id == null) return;
    var laconic = Database.instance.laconic;
    var json = tool.toJson();
    json.remove('id');
    await laconic.table('tools').where('id', tool.id).update(json);
  }

  Future<void> deleteTool(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('tools').where('id', id).delete();
  }

  Future<int> getToolsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('tools').count();
  }
}
