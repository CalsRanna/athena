import 'package:athena_gui/database/database.dart';
import 'package:athena_core/model/shortcut.dart';
import 'package:athena_core/repository/shortcut_repository.dart';

/// [ShortcutRepository] 的 SQLite 实现（GUI 侧）。
class SqliteShortcutRepository implements ShortcutRepository {
  @override
  Future<List<Shortcut>> getAllShortcuts() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('shortcuts').get();
    return results.map((r) => Shortcut.fromJson(r.toMap())).toList();
  }

  @override
  Future<Shortcut?> getShortcutById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('shortcuts').where('id', id).first();
      return Shortcut.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createShortcut(Shortcut shortcut) async {
    var laconic = Database.instance.laconic;
    var json = shortcut.toJson();
    json.remove('id');
    return await laconic.table('shortcuts').insertGetId(json);
  }

  @override
  Future<void> updateShortcut(Shortcut shortcut) async {
    if (shortcut.id == null) return;
    var laconic = Database.instance.laconic;
    var json = shortcut.toJson();
    json.remove('id');
    await laconic.table('shortcuts').where('id', shortcut.id).update(json);
  }

  @override
  Future<void> deleteShortcut(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('shortcuts').where('id', id).delete();
  }

  @override
  Future<void> batchCreateShortcuts(List<Shortcut> shortcuts) async {
    if (shortcuts.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = shortcuts.map((s) {
      var json = s.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('shortcuts').insert(jsonList);
  }

  @override
  Future<Shortcut?> getShortcutBySentinelId(int sentinelId) async {
    var laconic = Database.instance.laconic;
    try {
      var result =
          await laconic.table('shortcuts').where('sentinel_id', sentinelId).first();
      return Shortcut.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }
}
