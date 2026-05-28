import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/util/logger_util.dart';

class SkillRegistry {
  final SkillLoader _loader = SkillLoader();
  final Map<String, Skill> _skills = {};

  /// 当前 Agent 工具调用栈对应的 Skill 上下文。
  /// SkillTool 进入时 push，本轮工具调用结束后由 AgentService pop。
  final List<String> _contextStack = [];

  void loadAll() {
    _skills.clear();

    final home = _homePath;
    final userPath = '$home/.athena/skills';
    final userSkills = _loader.loadFromDirectory(userPath);
    for (final skill in userSkills) {
      _skills[skill.name] = skill;
    }

    // 项目级覆盖用户级。
    final projectPath = '${Directory.current.path}/.athena/skills';
    final projectSkills = _loader.loadFromDirectory(projectPath);
    for (final skill in projectSkills) {
      if (_skills.containsKey(skill.name)) {
        LoggerUtil.i(
          'Skill "${skill.name}" project-level override at ${skill.sourcePath}',
        );
      }
      _skills[skill.name] = skill;
    }
  }

  String get level1Prompt {
    if (_skills.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('## Available Skills');
    buffer.writeln('You have access to the following skills. '
        'Use the "skill" tool to load one when it would help with the task.');
    buffer.writeln();
    for (final skill in _skills.values) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  String? getLevel2Content(String name) {
    return _skills[name]?.body;
  }

  Skill? get(String name) => _skills[name];

  List<Skill> get all => _skills.values.toList();

  void pushContext(String skillName) {
    _contextStack.add(skillName);
  }

  void popContext() {
    if (_contextStack.isNotEmpty) _contextStack.removeLast();
  }

  void clearContext() {
    _contextStack.clear();
  }

  /// 当前 Agent 处于的最近一个 Skill 上下文。
  Skill? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _skills[_contextStack.last];
  }

  /// 在当前 Skill 上下文下重新解释工具的危险等级：
  /// - 不在任何 Skill 上下文中：返回工具默认等级；
  /// - SkillTool 自身不受约束：返回默认等级；
  /// - forbidden 永远不变；
  /// - 当前 Skill 声明了 allowedTools 且工具在列表中：降级为 safe；
  /// - 当前 Skill 声明了 allowedTools 但工具不在列表中：强制 needsApproval（即便默认 safe）；
  /// - 当前 Skill 未声明 allowedTools：保持默认等级，行为不变。
  DangerLevel effectiveDangerLevel(String toolName, DangerLevel defaultLevel) {
    if (defaultLevel == DangerLevel.forbidden) return defaultLevel;
    if (toolName == 'skill') return defaultLevel;
    final skill = currentContext;
    if (skill == null) return defaultLevel;

    final allowed = _parseAllowedTools(skill.allowedTools);
    if (allowed == null) return defaultLevel;

    if (allowed.contains(toolName)) return DangerLevel.safe;
    return DangerLevel.needsApproval;
  }

  static Set<String>? _parseAllowedTools(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
