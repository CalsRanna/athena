import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/database/database.dart';
import 'package:laconic/laconic.dart';

/// 删除 messages.expanded 列：推理卡片的展开状态改为 UI 内存态，不再持久化。
///
/// 采用「建新表 → 拷贝 → 删旧表 → 改名 → 重建索引」的重建方式，而不是
/// `ALTER TABLE DROP COLUMN`：应用使用各平台系统自带的 SQLite，部分环境
/// （旧版 Linux 发行版 / Android / winsqlite3）低于 3.35，不支持 DROP COLUMN。
///
/// 幂等：通过 marker 判断是否已执行；若列已不存在（异常路径）则只写 marker。
class Migration202609200001DropMessageExpanded {
  static const name = 'migration_202609200001_drop_message_expanded';

  /// 测试可注入内存实例；生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202609200001DropMessageExpanded({Laconic? laconic})
    : _laconic = laconic;

  Future<void> migrate() async {
    var laconic = _laconic ?? Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      if (await _hasExpandedColumn(laconic)) {
        await _rebuildMessagesTable(laconic);
        LoggerUtil.i('Migration $name: dropped messages.expanded');
      } else {
        LoggerUtil.i('Migration $name: expanded column absent, marker only');
      }

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  Future<bool> _hasExpandedColumn(Laconic laconic) async {
    var info = await laconic.select("PRAGMA table_info('messages')");
    return info.any((row) => row.toMap()['name'] == 'expanded');
  }

  Future<void> _rebuildMessagesTable(Laconic laconic) async {
    // 列集合 = init + add_tool_fields + add_compacted，去掉 expanded；
    // 外键与索引与原表保持一致。
    await laconic.statement('''
      CREATE TABLE messages_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        reasoning_content TEXT DEFAULT '',
        reasoning INTEGER DEFAULT 0,
        image_urls TEXT DEFAULT '',
        reference TEXT DEFAULT '',
        tool_calls TEXT DEFAULT '',
        tool_results TEXT DEFAULT '',
        compacted INTEGER DEFAULT 0,
        reasoning_started_at INTEGER NOT NULL,
        reasoning_updated_at INTEGER NOT NULL,
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    await laconic.statement('''
      INSERT INTO messages_new (id, chat_id, role, content, reasoning_content,
                                reasoning, image_urls, reference, tool_calls,
                                tool_results, compacted, reasoning_started_at,
                                reasoning_updated_at)
      SELECT id, chat_id, role, content, reasoning_content,
             reasoning, image_urls, reference, tool_calls,
             tool_results, compacted, reasoning_started_at,
             reasoning_updated_at
      FROM messages
    ''');

    await laconic.statement('DROP TABLE messages');
    await laconic.statement('ALTER TABLE messages_new RENAME TO messages');
    await laconic.statement(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id)',
    );
  }
}
