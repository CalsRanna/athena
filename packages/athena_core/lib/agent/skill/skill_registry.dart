import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';

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
  final Map<String, int> _skillAccessTimestamps = {};

  /// 当前 Agent 工具调用栈对应的 Skill 上下文。
  /// SkillTool 进入时 push，本轮工具调用结束后由 AgentService pop。
  final List<String> _contextStack = [];

  void loadAll({String? homeDir}) {
    _homeDir = homeDir ?? _homePath;

    _skills.clear();
    _skillAccessTimestamps.removeWhere((k, _) => !_builtinSkills.containsKey(k));

    final userSkillsPath = '$_homeDir/.athena/skills';
    final userSkills = _loader.loadFromDirectory(userSkillsPath);
    for (final skill in userSkills) {
      _skills[skill.name] = skill;
    }
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
        return tB.compareTo(tA);
      });

    final display = sorted.take(maxLevel1Skills).toList();
    final remaining = sorted.length - display.length;

    final buffer = StringBuffer();
    buffer.writeln('## Available Skills');
    buffer.writeln('You have access to the following skills. '
        'Use the "skill" tool to load one when it would help with the task.');
    if (remaining > 0) {
      buffer.writeln('(${display.length} shown, $remaining more available. '
          'Use the "skill" tool to load any by name.)');
    }
    buffer.writeln();
    for (final skill in display) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  String? getLevel2Content(String name) {
    _skillAccessTimestamps[name] = DateTime.now().millisecondsSinceEpoch;
    return _skills[name]?.body ?? _builtinSkills[name]?.body;
  }

  Skill? get(String name) {
    _skillAccessTimestamps[name] = DateTime.now().millisecondsSinceEpoch;
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

  Skill? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _skills[_contextStack.last];
  }

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
