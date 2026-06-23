import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 为 chats 表添加 token_total 列，持久化每个会话累计消耗的 token 总量。
///
/// - chats 表：新增 token_total INTEGER DEFAULT 0
///
/// 由 AgentStreamDelegate 在每次推理调用返回 usage 时累加并落库，
/// 使"会话累计 token"指标跨重启 / 会话切换保留。
class Migration202606230001AddChatTokenTotal {
  static const name = 'migration_202606230001_add_chat_token_total';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await _addColumnIfNotExists(
        laconic,
        table: 'chats',
        column: 'token_total',
        definition: 'INTEGER DEFAULT 0',
      );

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  Future<void> _addColumnIfNotExists(
    dynamic laconic, {
    required String table,
    required String column,
    required String definition,
  }) async {
    var result = await laconic.select(
      'PRAGMA table_info($table)',
    );
    var columns = result.map((r) => r.toMap()['name'] as String).toList();
    if (!columns.contains(column)) {
      await laconic.statement(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
      LoggerUtil.i('Migration $name: added $column to $table');
    }
  }
}