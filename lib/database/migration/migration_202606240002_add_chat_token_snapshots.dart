import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 为 chats 表添加上下文窗口占用与缓存命中率的快照列。
///
/// - context_tokens INTEGER DEFAULT 0：最近一次推理调用的 prompt token 数，
///   用于计算"上下文窗口占用率"（context_tokens / model.contextWindow）。
/// - cached_tokens INTEGER DEFAULT 0：最近一次推理调用中命中的缓存 token 数，
///   用于计算"缓存命中率"（cached_tokens / context_tokens）。
///
/// 两列均为每轮 usage 事件到达时覆盖写（非累加），反映最新状态。
class Migration202606240002AddChatTokenSnapshots {
  static const name = 'migration_202606240002_add_chat_token_snapshots';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await _addColumnIfNotExists(
        laconic,
        table: 'chats',
        column: 'context_tokens',
        definition: 'INTEGER DEFAULT 0',
      );
      await _addColumnIfNotExists(
        laconic,
        table: 'chats',
        column: 'cached_tokens',
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