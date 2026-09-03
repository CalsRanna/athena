import 'package:athena_gui/database/database.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:laconic/laconic.dart';

/// 为 chats 表添加 reasoning_effort 列，持久化每个会话的 OpenAI 推理强度。
///
/// - chats 表：新增 reasoning_effort TEXT（可空，NULL = 不传参、使用模型默认）
///
/// 取值与 OpenAI 官方 reasoning_effort 一致（low/medium/high/none/minimal/xhigh），
/// 由 ChatCompletionsService.getCompletion 在请求时解析为 official 枚举。
class Migration202608240001AddChatReasoningEffort {
  static const name = 'migration_202608240001_add_chat_reasoning_effort';

  /// 测试可注入内存实例；生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202608240001AddChatReasoningEffort({Laconic? laconic})
    : _laconic = laconic;

  Future<void> migrate() async {
    var laconic = _laconic ?? Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var result = await laconic.select('PRAGMA table_info(chats)');
      var columns = result.map((r) => r.toMap()['name'] as String).toList();
      if (!columns.contains('reasoning_effort')) {
        await laconic.statement(
          'ALTER TABLE chats ADD COLUMN reasoning_effort TEXT',
        );
        LoggerUtil.i('Migration $name: added reasoning_effort to chats');
      }

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
