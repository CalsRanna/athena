import 'package:athena/database/database.dart';

class Migration202605210001AddToolFields {
  static const name = 'migration_202605210001_add_tool_fields';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.statement(
      "ALTER TABLE messages ADD COLUMN tool_calls TEXT DEFAULT ''",
    );

    await laconic.statement(
      "ALTER TABLE messages ADD COLUMN tool_results TEXT DEFAULT ''",
    );

    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
