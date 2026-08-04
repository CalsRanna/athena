import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/model/shortcut.dart';
import 'package:athena_core/util/logger_util.dart';

/// 内置 Shortcut seed：5 个内置快捷入口，每个绑定一个 is_preset 专属
/// Sentinel（能力配置），并声明 page_target（定制 UI 标识）。
///
/// 通过 migrations 表 marker 去重（与既有 preset seed 机制一致）。
class Migration202608040002SeedShortcuts {
  static const name = 'migration_202608040002_seed_shortcuts';
  static const shortcutsMarker = 'preset_shortcuts_v1';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await _seedShortcuts();
      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  Future<void> _seedShortcuts() async {
    var laconic = Database.instance.laconic;

    var done = await laconic
        .table('migrations')
        .where('name', shortcutsMarker)
        .count();
    if (done > 0) return;

    // 1. 创建 5 个专属 Sentinel（is_preset=true）
    final sentinels = [
      SentinelEntity(
        name: 'Translation',
        avatar: '🔄',
        description: 'Translate input into selected language',
        prompt: 'You are a professional translator. Translate the user input '
            'into the target language accurately, preserving tone and nuance.',
        tags: 'shortcut',
        isPreset: true,
      ),
      SentinelEntity(
        name: 'Summary',
        avatar: '📝',
        description: 'Summary the content in the internet link',
        prompt: 'You are a summarization expert. Given a link or text, produce '
            'a clear, structured summary of the key points.',
        tags: 'shortcut',
        isPreset: true,
      ),
      SentinelEntity(
        name: 'Food',
        avatar: '🍳',
        description: 'Give you a recipe suggestion of healthy food',
        prompt: 'You are a culinary assistant. Given a request, suggest a '
            'healthy, balanced recipe with ingredients and steps.',
        tags: 'shortcut',
        isPreset: true,
      ),
      SentinelEntity(
        name: 'Code',
        avatar: '💻',
        description: 'Give you a code suggestion about variables, functions, etc',
        prompt: 'You are a coding expert. Given a question, provide clear, '
            'idiomatic code suggestions with brief explanations.',
        tags: 'shortcut',
        isPreset: true,
      ),
      SentinelEntity(
        name: 'TRPG',
        avatar: '🎲',
        description: 'Play an unique tabletop role-playing game.',
        prompt: 'You are the game master of a tabletop role-playing game. '
            'Drive the story, respond to player actions, and keep the game '
            'immersive and fair.',
        tags: 'shortcut',
        isPreset: true,
      ),
    ];

    final sentinelIds = <int>[];
    for (final sentinel in sentinels) {
      var json = sentinel.toJson();
      json.remove('id');
      var id = await laconic.table('sentinels').insertGetId(json);
      sentinelIds.add(id);
    }

    // 2. 创建 5 个 Shortcut，绑定上面的 Sentinel，声明 page_target
    final shortcuts = [
      Shortcut(
        name: 'Translation',
        description: 'Translate input into selected language',
        icon: '',
        pageTarget: 'translation',
        sentinelId: sentinelIds[0],
      ),
      Shortcut(
        name: 'Summary',
        description: 'Summary the content in the internet link',
        icon: '',
        pageTarget: 'summary',
        sentinelId: sentinelIds[1],
      ),
      Shortcut(
        name: 'Food',
        description: 'Give you a recipe suggestion of healthy food',
        icon: '',
        pageTarget: null,
        sentinelId: sentinelIds[2],
      ),
      Shortcut(
        name: 'Code',
        description: 'Give you a code suggestion about variables, functions, etc',
        icon: '',
        pageTarget: null,
        sentinelId: sentinelIds[3],
      ),
      Shortcut(
        name: 'TRPG',
        description: 'Play an unique tabletop role-playing game.',
        icon: '',
        pageTarget: 'trpg',
        sentinelId: sentinelIds[4],
      ),
    ];

    final shortcutJsonList = shortcuts.map((s) {
      var json = s.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('shortcuts').insert(shortcutJsonList);

    await laconic.table('migrations').insert([
      {'name': shortcutsMarker},
    ]);
    LoggerUtil.i('Migration $name: seeded ${shortcuts.length} shortcuts');
  }
}
