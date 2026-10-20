import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

class SkillRegistry {
  /// Level 1 技能列表最大条数。超过此数量后，仅显示最近使用的技能。
  static const int maxLevel1Skills = 20;

  final SkillLoader _loader = SkillLoader();
  final Map<String, Skill> _skills = {};

  /// loadAll 传入的用户级 Skill 目录（供 reloadSkill 复用，避免与
  /// 环境变量 HOME 不一致——测试与自定义 home 场景下两者可能不同）。
  String? _homeDir;

  /// 内置 Skill：不来自文件系统，由代码注册，始终可用。
  final Map<String, Skill> _builtinSkills = {};

  /// Skill 最近访问时间戳（毫秒），用于 level1 排序。
  ///
  /// 落盘到 `skills/.usage.json`：只存内存时，每次启动所有用户技能都是 0 分
  /// 并列，而 `List.sort` 对并列项不保证稳定、输入顺序又来自文件系统枚举——
  /// 于是技能目录的顺序可能每次启动都不同。那既破坏了 prompt prefix cache，
  /// 也让「超出 20 条时藏起哪几条」变得不可预测。
  final Map<String, int> _skillAccessTimestamps = {};

  /// 当前 Agent 工具调用栈对应的 Skill 上下文。
  /// SkillTool 进入时 push，本轮工具调用结束后由 AgentService pop。
  final List<String> _contextStack = [];

  /// 访问时间的落盘是否启用（未 loadAll 过时为 false，避免误写文件）。
  bool _usageLoaded = false;

  void loadAll({String? homeDir}) {
    _homeDir = homeDir ?? _homePath;

    _skills.clear();
    _skillAccessTimestamps.removeWhere(
      (k, _) => !_builtinSkills.containsKey(k),
    );

    final userSkillsPath = '$_homeDir/.athena/skills';
    final userSkills = _loader.loadFromDirectory(userSkillsPath);
    for (final skill in userSkills) {
      _skills[skill.name] = skill;
    }
    _loadUsage();
  }

  void registerBuiltin(Skill skill) {
    _builtinSkills[skill.name] = skill;
    _skillAccessTimestamps[skill.name] = DateTime.now().millisecondsSinceEpoch;
  }

  String get level1Prompt {
    final allSkills = <String, Skill>{};
    allSkills.addAll(_skills);
    allSkills.addAll(_builtinSkills);

    if (allSkills.isEmpty) return '';

    final sorted = allSkills.values.toList()
      ..sort((a, b) {
        final tA = _skillAccessTimestamps[a.name] ?? 0;
        final tB = _skillAccessTimestamps[b.name] ?? 0;
        final byAccess = tB.compareTo(tA);
        // 并列时按名称定序：文件枚举顺序不是稳定输入，不能让它决定
        // 「哪 20 条被显示」以及 prompt 的字节内容。
        return byAccess != 0 ? byAccess : a.name.compareTo(b.name);
      });

    final display = sorted.take(maxLevel1Skills).toList();
    final remaining = sorted.length - display.length;

    final buffer = StringBuffer();
    buffer.writeln('## 可用技能');
    buffer.writeln(
      '你可以使用以下技能。技能有助于当前任务时，'
      '使用 "skill" 工具加载相应技能。',
    );
    if (remaining > 0) {
      buffer.writeln(
        '（已显示 ${display.length} 个，另有 $remaining 个可用。'
        '使用 "skill" 工具按名称加载任意技能。）',
      );
    }
    buffer.writeln();
    for (final skill in display) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  String? getLevel2Content(String name) {
    _noteAccess(name);
    return _skills[name]?.body ?? _builtinSkills[name]?.body;
  }

  Skill? get(String name) {
    _noteAccess(name);
    return _skills[name] ?? _builtinSkills[name];
  }

  List<Skill> get all {
    final result = <Skill>[];
    result.addAll(_skills.values);
    result.addAll(_builtinSkills.values);
    return result;
  }

  void pushContext(String skillName) {
    _contextStack.add(skillName);
  }

  void popContext() {
    if (_contextStack.isNotEmpty) _contextStack.removeLast();
  }

  void clearContext() {
    _contextStack.clear();
  }

  /// skill_evolve 创建/更新 Skill 后重新加载单个文件（写入即生效，无需全量 reload）。
  void reloadSkill(String skillName, String directoryPath) {
    final skillFile = File('$directoryPath/SKILL.md');
    if (!skillFile.existsSync()) {
      _skills.remove(skillName);
      return;
    }
    final skill = _loader.parseSkillFile(skillFile);
    if (skill == null) return;
    _skills[skillName] = skill;
  }

  /// 重新扫描用户级 Skill 目录（复用最近一次 [loadAll] 的 homeDir）。
  /// 内置 Skill 不受影响。
  void reload() {
    loadAll(homeDir: _homeDir);
  }

  /// 删除用户级 Skill：删除其目录并从内存移除。
  ///
  /// 内置 Skill（如 self-evolve）或未找到时返回 false，不做任何删除。
  bool deleteSkill(String name) {
    final skill = _skills[name];
    if (skill == null) return false;
    final dir = Directory(skill.sourcePath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    _skills.remove(name);
    _skillAccessTimestamps.remove(name);
    if (_usageLoaded) _saveUsage();
    return true;
  }

  /// 用户级 Skill 根目录（`{homeDir}/.athena/skills`）。
  ///
  /// 以最近一次 [loadAll] 的 homeDir 为准；新建 Skill 的落盘目录由此计算。
  String get skillsDirectory => '${_homeDir ?? _homePath}/.athena/skills';

  Skill? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _skills[_contextStack.last];
  }

  /// 访问时间文件：与技能目录同级，`skills/.usage.json`。
  File get _usageFile => File(p.join(skillsDirectory, '.usage.json'));

  void _noteAccess(String name) {
    _skillAccessTimestamps[name] = DateTime.now().millisecondsSinceEpoch;
    // 加载技能是低频动作（一次 run 通常几次），写一个小 JSON 的代价远低于
    // 顺序漂移带来的缓存失效。失败不阻断：内存值仍然生效。
    if (_usageLoaded) _saveUsage();
  }

  void _loadUsage() {
    final file = _usageFile;
    _usageLoaded = true;
    if (!file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic>) return;
      for (final entry in json.entries) {
        final value = entry.value;
        if (value is int) _skillAccessTimestamps[entry.key] = value;
      }
    } catch (e) {
      // 损坏只影响排序新鲜度，重建即可，不该阻断技能加载。
      LoggerUtil.w('Skill usage timestamps unreadable (${file.path}): $e');
    }
  }

  void _saveUsage() {
    try {
      // 只留当前存在的用户技能，避免文件随时间无界增长。
      final known = <String, int>{
        for (final skill in _skills.values)
          if (_skillAccessTimestamps.containsKey(skill.name))
            skill.name: _skillAccessTimestamps[skill.name]!,
      };
      _usageFile.parent.createSync(recursive: true);
      _usageFile.writeAsStringSync(jsonEncode(known));
    } catch (e) {
      // 排序信号写不进去不该让 skill 工具报错；下次访问会重试。
      LoggerUtil.w('Failed to persist skill usage (${_usageFile.path}): $e');
    }
  }

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
