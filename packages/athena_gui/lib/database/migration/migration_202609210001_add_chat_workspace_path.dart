import 'package:athena_gui/database/database.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:laconic/laconic.dart';

/// 为 chats 表添加 workspace_path 列，持久化每个会话可选的工作文件夹。
///
/// - chats 表：新增 workspace_path TEXT（可空，NULL = 不指定）
///
/// 非空时该会话的 shell 默认工作目录与文件工具的相对路径基准都落在该目录；
/// 由 AgentRunCoordinator 在每次 run 开始时读取并校验（目录失效则降级为
/// 不指定并记日志）。只能按会话存：多对话可同时运行，进程级基准会串台。
class Migration202609210001AddChatWorkspacePath {
  static const name = 'migration_202609210001_add_chat_workspace_path';

  /// 测试可注入内存实例；生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202609210001AddChatWorkspacePath({Laconic? laconic})
    : _laconic = laconic;

  Future<void> migrate() async {
    var laconic = _laconic ?? Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var result = await laconic.select('PRAGMA table_info(chats)');
      var columns = result.map((r) => r.toMap()['name'] as String).toList();
      if (!columns.contains('workspace_path')) {
        await laconic.statement(
          'ALTER TABLE chats ADD COLUMN workspace_path TEXT',
        );
        LoggerUtil.i('Migration $name: added workspace_path to chats');
      }

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
