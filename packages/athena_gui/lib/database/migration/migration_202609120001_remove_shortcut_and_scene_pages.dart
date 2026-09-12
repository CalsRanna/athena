import 'package:athena_gui/database/database.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:laconic/laconic.dart';

/// 移除 Shortcut 特性与三个场景页（Translation/Summary/TRPG）的遗留数据：
/// - DROP shortcuts / trpg_messages / trpg_games 表
/// - 把引用 seed preset Sentinel 的 chats.sentinel_id 归 0（会话保留）
/// - 删除 tags='shortcut' 且 is_preset=1 的 seed Sentinel
/// - 清理已删除迁移的 marker，避免旧库残留记录
///
/// 幂等：通过自身 marker 判断是否已执行；全新库（无遗留表/数据）上全部为 no-op。
class Migration202609120001RemoveShortcutAndScenePages {
  static const name = 'migration_202609120001_remove_shortcut_and_scene_pages';

  /// 测试可注入内存实例；生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202609120001RemoveShortcutAndScenePages({Laconic? laconic})
    : _laconic = laconic;

  Future<void> migrate() async {
    var laconic = _laconic ?? Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await laconic.statement('DROP TABLE IF EXISTS shortcuts');
      await laconic.statement('DROP TABLE IF EXISTS trpg_messages');
      await laconic.statement('DROP TABLE IF EXISTS trpg_games');

      // chats.sentinel_id 无外键约束，删除 Sentinel 前需显式解除引用
      await laconic.statement('''
        UPDATE chats SET sentinel_id = 0
        WHERE sentinel_id IN (
          SELECT id FROM sentinels WHERE is_preset = 1 AND tags = 'shortcut'
        )
      ''');

      await laconic.statement(
        "DELETE FROM sentinels WHERE is_preset = 1 AND tags = 'shortcut'",
      );

      await laconic.statement('''
        DELETE FROM migrations WHERE name IN (
          'migration_202608040001_create_shortcuts',
          'migration_202608040002_seed_shortcuts',
          'preset_shortcuts_v1',
          'migration_202501200002_add_trpg_tables',
          'migration_202501210001_add_suggestions_to_trpg_messages',
          'migration_202501210002_simplify_trpg_games'
        )
      ''');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
      LoggerUtil.i('Migration $name: removed shortcut & scene-page artifacts');
    });
  }
}
